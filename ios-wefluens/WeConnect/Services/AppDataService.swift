//
//  AppDataService.swift
//  WeConnect
//
//  Central data service that bridges Supabase rows ↔ domain models.
//  Falls back to SampleData when the user is not authenticated.
//

import Foundation
import Supabase
import UIKit

@Observable
final class AppDataService {
    var conversations: [Conversation] = []
    var contacts: [Contact] = []
    var friendRequests: [FriendRequest] = []
    /// Names of people who accepted a request *I* sent, not yet shown to me.
    /// Drives the in-app "X accepted your friend request" prompt.
    var friendAcceptedNames: [String] = []
    var brands: [Brand] = []
    var campaigns: [Campaign] = []
    var profile: UserProfile?

    /// UUIDs of users I've blocked. Maintained in memory and refreshed by
    /// `loadBlocks()` / `blockUser` / `unblockUser`. Used to filter blocked users
    /// out of conversations, contacts, group messages, and friend search so a
    /// blocked person disappears from every surface (Trust & Safety / Guideline 1.2).
    var blockedUserIds: Set<UUID> = []

    /// Ids of conversations I've pinned to the top of my chat list (置顶) and
    /// muted (消息免打扰). Local-only, on-device prefs (WeChat-style): pinned sorts
    /// to the top, muted hides the unread badge contribution. Persisted to
    /// UserDefaults as a JSON array of uuid strings; loaded once in `init`.
    var pinnedIds: Set<UUID> = []
    var mutedIds: Set<UUID> = []

    /// Local-only friend remarks (备注), WeChat-style: a custom display name I set
    /// for a friend that only I see. Maps a friend's uuid string → remark text.
    /// Persisted to UserDefaults as a JSON object; loaded once in `init`. Published
    /// (it's a stored property on this `@Observable`), so setting a remark refreshes
    /// the contact list / detail immediately.
    var remarks: [String: String] = [:]

    /// Cloud-synced favorites (收藏) of chat messages (Supabase `favorites` table).
    /// Held here so every screen that already has the `AppDataService` in scope
    /// (chats, group chats, profile) can read/write favorites without a separate
    /// environment object. It's @Observable, so list views observing `data.favorites`
    /// refresh the moment a favorite is added or removed.
    let favorites = FavoritesStore()

    /// Local-only pinned group messages (群公告), one per group, persisted on-device.
    /// Held here so the group chat view can read/write the pinned banner through the
    /// existing `AppDataService` in scope. It's @Observable, so the banner refreshes
    /// the moment a message is pinned or unpinned.
    let pinnedMessages = PinnedMessageStore()

    /// In-memory LRU of decoded chat images, keyed by storage path. Backs the
    /// on-device media cache (see `cachedChatImage`). Not observable state.
    @ObservationIgnored private let imageMemoryCache = NSCache<NSString, UIImage>()

    private static let pinnedKey = "wefluens.pinned"
    private static let mutedKey = "wefluens.muted"
    private static let remarksKey = "wefluens.remarks"

    var isLoadingConversations = false
    var isLoadingContacts = false
    var isLoadingProfile = false

    let userId: UUID?

    init(userId: UUID?) {
        self.userId = userId
        self.pinnedIds = Self.loadIdSet(forKey: Self.pinnedKey)
        self.mutedIds = Self.loadIdSet(forKey: Self.mutedKey)
        self.remarks = Self.loadStringMap(forKey: Self.remarksKey)
        self.favorites.configure(userId: userId)
    }

    // MARK: - Friend Remarks (备注)

    /// The custom remark I've set for a friend, or nil when none. Empty strings are
    /// treated as "no remark" so a cleared field falls back to the real name.
    func remark(for id: UUID) -> String? {
        let value = remarks[id.uuidString]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    /// Sets (or clears, when trimmed-empty) a friend's remark and persists it.
    func setRemark(_ remark: String, for id: UUID) {
        let trimmed = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            remarks.removeValue(forKey: id.uuidString)
        } else {
            remarks[id.uuidString] = trimmed
        }
        Self.saveStringMap(remarks, forKey: Self.remarksKey)
    }

    /// The name to show for a friend: their remark when set, otherwise their real name.
    func displayName(for contact: Contact) -> String {
        remark(for: contact.id) ?? contact.name
    }

    // MARK: - Conversation Prefs (pin / mute)

    /// True when the conversation is pinned to the top of my chat list.
    func isPinned(_ id: UUID) -> Bool { pinnedIds.contains(id) }

    /// True when the conversation is muted (免打扰) — its unread count is excluded
    /// from the Chats tab badge.
    func isMuted(_ id: UUID) -> Bool { mutedIds.contains(id) }

    /// Pins / unpins a conversation and persists the change.
    func setPinned(_ id: UUID, on: Bool) {
        if on { pinnedIds.insert(id) } else { pinnedIds.remove(id) }
        Self.saveIdSet(pinnedIds, forKey: Self.pinnedKey)
    }

    /// Mutes / unmutes a conversation and persists the change.
    func setMuted(_ id: UUID, on: Bool) {
        if on { mutedIds.insert(id) } else { mutedIds.remove(id) }
        Self.saveIdSet(mutedIds, forKey: Self.mutedKey)
    }

    /// Reads a stored set of UUIDs from UserDefaults (JSON array of uuid strings).
    private static func loadIdSet(forKey key: String) -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }

    /// Persists a set of UUIDs to UserDefaults as a JSON array of uuid strings.
    private static func saveIdSet(_ ids: Set<UUID>, forKey key: String) {
        let strings = ids.map { $0.uuidString }
        if let data = try? JSONEncoder().encode(strings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Reads a stored [String: String] map from UserDefaults (JSON object).
    private static func loadStringMap(forKey key: String) -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }

    /// Persists a [String: String] map to UserDefaults as a JSON object.
    private static func saveStringMap(_ map: [String: String], forKey key: String) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Profile

    /// Full error info returned by data operations so the UI can show meaningful messages.
    struct DataError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @MainActor
    func syncProfile(userId: UUID, email: String?) async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            let rows: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value

            if let row = rows.first {
                profile = UserProfile(
                    name: row.name ?? email ?? "User",
                    handle: row.handle ?? "",
                    role: row.role ?? "",
                    bio: row.bio ?? "",
                    location: row.location ?? "",
                    followers: row.followers ?? "0",
                    engagement: row.engagement ?? "0%",
                    deals: row.deals ?? "0",
                    isAdmin: row.isAdmin ?? false,
                    avatarUrl: row.avatarUrl,
                    notificationsEnabled: row.notificationsEnabled ?? true,
                    activityStatus: row.activityStatus ?? true,
                    dataSharing: row.dataSharing ?? true
                )
            } else {
                // Profile row missing — create via upsert, then return fallback
                let upsert = ProfileUpsert(
                    id: userId, email: email, name: nil, avatarUrl: nil,
                    handle: nil, role: nil, bio: nil, location: nil,
                    followers: nil, engagement: nil, deals: nil, isAdmin: nil
                )
                try? await supabase.from("profiles").upsert(upsert).execute()
                profile = UserProfile(
                    name: email ?? "User", handle: "", role: "", bio: "",
                    location: "", followers: "0", engagement: "0%", deals: "0",
                    isAdmin: false, avatarUrl: nil
                )
            }
        } catch {
            print("⚠️ Profile sync failed: \(error.localizedDescription)")
            // Still create a minimal local profile so the UI isn't blank
            profile = UserProfile(
                name: email ?? "User", handle: "", role: "", bio: "",
                location: "", followers: "0", engagement: "0%", deals: "0",
                isAdmin: false, avatarUrl: nil
            )
        }
    }

    /// Re-fetch the profile from the database and update the local copy.
    /// Called after edits to guarantee the UI shows what's actually stored.
    @MainActor
    func refreshProfile() async {
        guard let uid = userId else { return }
        do {
            let rows: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: uid.uuidString)
                .execute()
                .value
            if let row = rows.first {
                profile = UserProfile(
                    name: row.name ?? "User",
                    handle: row.handle ?? "",
                    role: row.role ?? "",
                    bio: row.bio ?? "",
                    location: row.location ?? "",
                    followers: row.followers ?? "0",
                    engagement: row.engagement ?? "0%",
                    deals: row.deals ?? "0",
                    isAdmin: row.isAdmin ?? false,
                    avatarUrl: row.avatarUrl,
                    notificationsEnabled: row.notificationsEnabled ?? true,
                    activityStatus: row.activityStatus ?? true,
                    dataSharing: row.dataSharing ?? true
                )
            }
        } catch {
            print("⚠️ Profile refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Preferences (notifications / activity / data sharing)

    /// Persists the Push Notifications opt-in to the profile and updates the local
    /// copy. The send path (send-push) only delivers to users with this flag true.
    @MainActor
    func setNotificationsEnabled(_ on: Bool) async {
        guard let uid = userId else { return }
        profile?.notificationsEnabled = on
        do {
            try await supabase.from("profiles")
                .update(NotificationsPrefUpdate(notifications_enabled: on))
                .eq("id", value: uid.uuidString)
                .execute()
        } catch {
            print("⚠️ setNotificationsEnabled failed: \(error)")
        }
    }

    /// Persists the Activity Status preference (whether the online dot is visible).
    @MainActor
    func setActivityStatus(_ on: Bool) async {
        guard let uid = userId else { return }
        profile?.activityStatus = on
        do {
            try await supabase.from("profiles")
                .update(ActivityStatusUpdate(activity_status: on))
                .eq("id", value: uid.uuidString)
                .execute()
        } catch {
            print("⚠️ setActivityStatus failed: \(error)")
        }
    }

    /// Persists the Data Sharing preference (whether the user appears in the Top
    /// Talent directory).
    @MainActor
    func setDataSharing(_ on: Bool) async {
        guard let uid = userId else { return }
        profile?.dataSharing = on
        do {
            try await supabase.from("profiles")
                .update(DataSharingUpdate(data_sharing: on))
                .eq("id", value: uid.uuidString)
                .execute()
        } catch {
            print("⚠️ setDataSharing failed: \(error)")
        }
    }

    /// Submits an in-app support ticket via the `submit-support-ticket` edge
    /// function (records it in support_tickets and emails support@ via Resend).
    /// `type` is the feedback category ("bug" | "idea" | "other"). `images` are
    /// attachments (capped at 6); each is downscaled + JPEG-compressed (≈1600px)
    /// and base64-encoded into `{ dataBase64, mime: "image/jpeg" }`. The UI language
    /// is mapped to "zh" (Chinese) or "en" (everything else). Returns true on success.
    @MainActor
    func submitSupportTicket(
        subject: String,
        body: String,
        type: String = "other",
        language: AppLanguage = .english,
        images: [Data] = []
    ) async throws -> Bool {
        let lang = language == .chinese ? "zh" : "en"
        let encoded: [SupportTicketImage] = images.prefix(6).compactMap { raw in
            let compressed = Self.compressedJPEG(raw, maxDimension: 1600, quality: 0.7) ?? raw
            return SupportTicketImage(
                dataBase64: compressed.base64EncodedString(),
                mime: "image/jpeg"
            )
        }
        let resp: SupportTicketResponse = try await supabase.functions.invoke(
            "submit-support-ticket",
            options: .init(body: SupportTicketRequest(
                subject: subject,
                body: body,
                type: type,
                lang: lang,
                images: encoded
            ))
        )
        return resp.ok == true
    }

    /// Registers (upserts) this device's APNs token for the signed-in user. Called
    /// after the OS grants notification permission. The actual push send path is
    /// stubbed server-side (see backend send-push); this just records the token.
    @MainActor
    func registerDeviceToken(_ token: String) async {
        guard let uid = userId else { return }
        do {
            try await supabase.from("device_tokens")
                .upsert(DeviceTokenUpsert(user_id: uid.uuidString, token: token, platform: "ios"),
                        onConflict: "token")
                .execute()
        } catch {
            print("⚠️ registerDeviceToken failed: \(error)")
        }
    }

    // MARK: - Avatar

    /// Uploads a compressed avatar to the public `avatars` bucket and returns its
    /// public URL. THROWS on failure — the caller must surface the error and must
    /// NOT pretend the save succeeded. The path is `{uid}/avatar-{uuid}.jpg`
    /// (lowercased to match the Storage RLS policy).
    @MainActor
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        let compressed = Self.compressedJPEG(imageData, maxDimension: 512, quality: 0.82) ?? imageData
        let folder = userId.uuidString.lowercased()
        let filePath = "\(folder)/avatar-\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage
            .from("avatars")
            .upload(filePath, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        return publicURL.absoluteString
    }

    /// Downscales + JPEG-compresses image data so uploads stay small and fast.
    nonisolated static func compressedJPEG(_ data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Pixel dimensions of encoded image data (for chat image layout).
    nonisolated static func pixelSize(_ data: Data) -> (width: Int, height: Int)? {
        guard let image = UIImage(data: data) else { return nil }
        let w = Int((image.size.width * image.scale).rounded())
        let h = Int((image.size.height * image.scale).rounded())
        guard w > 0, h > 0 else { return nil }
        return (w, h)
    }

    /// Returns true if `handle` is free (case-insensitively) for someone other than
    /// `userId`. Mirrors RN's api.isHandleAvailable. On a query failure we return
    /// true so a transient error never blocks save — the DB unique index still guards.
    @MainActor
    func isHandleAvailable(handle: String, userId: UUID) async -> Bool {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let rows: [ProfileRow] = try await supabase
                .from("profiles")
                .select("id")
                .ilike("handle", value: trimmed)
                .neq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return rows.isEmpty
        } catch {
            return true
        }
    }

    /// Persist profile fields to Supabase via upsert — works even if the row
    /// was never created by syncProfile. Throws on failure so the caller can show an error.
    @MainActor
    func updateProfile(name: String, bio: String, location: String, handle: String? = nil, avatarUrl: String? = nil) async throws {
        guard let uid = userId else {
            throw DataError(message: "Not signed in")
        }

        // Upsert guarantees the row exists — safe even when syncProfile failed silently.
        // A nil `handle` is omitted by the encoder, so it's left unchanged.
        let upsert = ProfileUpsert(
            id: uid,
            email: nil,
            name: name,
            avatarUrl: avatarUrl,
            handle: handle,
            role: nil,
            bio: bio,
            location: location,
            followers: nil,
            engagement: nil,
            deals: nil,
            isAdmin: nil
        )
        try await supabase.from("profiles")
            .upsert(upsert)
            .execute()

        // Reflect changes locally immediately
        if profile != nil {
            profile?.name = name
            profile?.bio = bio
            profile?.location = location
            if let handle { profile?.handle = handle }
            // Always mirror the avatar (including a freshly uploaded one).
            profile?.avatarUrl = avatarUrl
        } else {
            profile = UserProfile(
                name: name, handle: "", role: "",
                bio: bio, location: location,
                followers: "0", engagement: "0%", deals: "0",
                isAdmin: false, avatarUrl: avatarUrl
            )
        }
    }

    // MARK: - Conversations

    /// Loads the conversation inbox: real 1:1 DM threads (`list_dm_threads`) and
    /// group threads (`list_group_threads`) in parallel, merged and sorted by the
    /// last-message time so DMs and groups interleave like one inbox. Each loader
    /// isolates its own errors so one failing can't blank the other.
    @MainActor
    func loadConversations() async {
        guard let uid = userId else {
            conversations = SampleData.conversations
            return
        }
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        async let dmsTask = loadDMThreads(uid: uid)
        async let groupsTask = loadGroupThreads(uid: uid)
        let dms = await dmsTask
        let groups = await groupsTask
        conversations = (dms + groups)
            // Hide 1:1 threads with users I've blocked (groups have no otherUserId).
            .filter { conv in
                guard let other = conv.otherUserId else { return true }
                return !blockedUserIds.contains(other)
            }
            .sorted {
                ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast)
            }
    }

    /// Loads my 1:1 DM threads via `list_dm_threads`. Returns [] on error so a
    /// group-load failure can't blank the DMs (and vice-versa).
    @MainActor
    private func loadDMThreads(uid: UUID) async -> [Conversation] {
        do {
            let rows: [DMThreadListRow] = try await supabase
                .rpc("list_dm_threads")
                .execute()
                .value

            return rows.map { row in
                let displayName = row.otherName ?? row.otherHandle ?? "User"
                return Conversation(
                    id: row.threadId,
                    name: displayName,
                    avatar: "person.fill",
                    avatarColors: Self.avatarPalette(for: row.otherId),
                    lastMessage: row.lastMessage ?? "",
                    time: Self.relativeTime(from: row.lastMessageAt),
                    unread: max(0, row.unreadCount),
                    isPinned: false,
                    isOfficial: false,
                    isOnline: false,
                    isGroup: false,
                    participantCount: 0,
                    messages: [],
                    otherUserId: row.otherId,
                    avatarInitials: Self.initials(from: displayName),
                    lastMessageAt: row.lastMessageAt,
                    lastFromMe: row.lastSenderId == uid,
                    lastMessageIsImage: (row.lastMessageType ?? "text") == "image",
                    lastMessageType: row.lastMessageType ?? "text",
                    lastMessageRecalled: row.lastMessageRecalled ?? false,
                    avatarUrl: row.otherAvatarUrl
                )
            }
        } catch {
            print("⚠️ DM threads load failed: \(error)")
            return []
        }
    }

    /// Loads my group threads via `list_group_threads` (member count + last-message
    /// preview + my unread count). Returns [] on error. Groups render with a
    /// `person.3.fill` symbol avatar (no per-group photo yet).
    @MainActor
    private func loadGroupThreads(uid: UUID) async -> [Conversation] {
        do {
            // Compute @me mentions concurrently with the thread list (client-side,
            // mirrors the RN app — no backend change needed).
            async let mentionedTask = loadMentionedGroupIds(uid: uid)
            let rows: [GroupThreadListRow] = try await supabase
                .rpc("list_group_threads")
                .execute()
                .value
            let mentionedSet = await mentionedTask

            return rows.map { row in
                let displayName = (row.name.flatMap { $0.isEmpty ? nil : $0 }) ?? "Group"
                return Conversation(
                    id: row.groupId,
                    name: displayName,
                    avatar: "person.3.fill",
                    avatarColors: Self.avatarPalette(for: row.groupId),
                    lastMessage: row.lastMessage ?? "",
                    time: Self.relativeTime(from: row.lastMessageAt),
                    unread: max(0, row.unreadCount),
                    isPinned: false,
                    isOfficial: false,
                    isOnline: false,
                    isGroup: true,
                    participantCount: row.memberCount,
                    messages: [],
                    otherUserId: nil,
                    avatarInitials: nil,
                    lastMessageAt: row.lastMessageAt,
                    lastFromMe: row.lastSenderId == uid,
                    lastMessageIsImage: (row.lastMessageType ?? "text") == "image",
                    lastMessageType: row.lastMessageType ?? "text",
                    lastMessageRecalled: row.lastMessageRecalled ?? false,
                    avatarUrl: row.avatarUrl,
                    mentioned: mentionedSet.contains(row.groupId)
                )
            }
        } catch {
            print("⚠️ Group threads load failed: \(error)")
            return []
        }
    }

    private struct GroupMemberReadRow: Decodable {
        let groupId: UUID
        let lastReadAt: Date?
        enum CodingKeys: String, CodingKey { case groupId = "group_id"; case lastReadAt = "last_read_at" }
    }

    private struct GroupMentionRow: Decodable {
        let groupId: UUID
        let body: String
        let createdAt: Date?
        enum CodingKeys: String, CodingKey { case groupId = "group_id"; case body; case createdAt = "created_at" }
    }

    /// Group ids where an unread message (created after my last_read_at) @-mentions
    /// me. Two batched queries; the @me match runs client-side via Mentions.
    @MainActor
    private func loadMentionedGroupIds(uid: UUID) async -> Set<UUID> {
        var result = Set<UUID>()
        let myName = profile?.name ?? ""
        do {
            let members: [GroupMemberReadRow] = try await supabase
                .from("group_members")
                .select("group_id,last_read_at")
                .eq("user_id", value: uid.uuidString)
                .execute()
                .value
            if members.isEmpty { return result }
            var lastRead: [UUID: Date] = [:]
            var groupIds: [String] = []
            for m in members {
                if let lr = m.lastReadAt { lastRead[m.groupId] = lr }
                groupIds.append(m.groupId.uuidString)
            }
            let msgs: [GroupMentionRow] = try await supabase
                .from("group_messages")
                .select("group_id,body,created_at,sender_id")
                .in("group_id", values: groupIds)
                .neq("sender_id", value: uid.uuidString)
                .ilike("body", pattern: "%@%")
                .order("created_at", ascending: false)
                .limit(300)
                .execute()
                .value
            for m in msgs {
                if result.contains(m.groupId) { continue }
                if let lr = lastRead[m.groupId], let created = m.createdAt, created <= lr { continue }
                if Mentions.messageMentionsMe(m.body, myName: myName) { result.insert(m.groupId) }
            }
        } catch {
            print("⚠️ Mentioned group ids failed: \(error)")
        }
        return result
    }

    // MARK: - Contacts

    @MainActor
    func loadContacts() async {
        guard let uid = userId else {
            contacts = SampleData.contacts
            friendRequests = SampleData.friendRequests
            return
        }
        isLoadingContacts = true
        defer { isLoadingContacts = false }

        // Refresh the block list first so blocked friends are filtered out below.
        await loadBlocks()

        do {
            // Friends are derived from the `friendships` graph (the source of truth
            // for both the contact list and the count). Each accepted request
            // produces two rows, so "my friends" is simply user_id = me.
            let links: [FriendshipFriendRow] = try await supabase
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: uid.uuidString)
                .execute()
                .value

            let friendIds = links.map { $0.friendId.uuidString }
            if friendIds.isEmpty {
                contacts = []
            } else {
                let profs: [ProfileRow] = try await supabase
                    .from("profiles")
                    .select()
                    .in("id", values: friendIds)
                    .execute()
                    .value
                contacts = profs
                    .map { contact(from: $0) }
                    .filter { !blockedUserIds.contains($0.id) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

            // Pending friend requests addressed to me (the "New Friends" section).
            let fRows: [FriendRequestDBRow] = try await supabase
                .from("friend_requests")
                .select()
                .eq("to_user_id", value: uid.uuidString)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            friendRequests = fRows.map { row in
                FriendRequest(
                    id: row.id,
                    name: row.name,
                    handle: row.handle ?? "",
                    role: row.role ?? "",
                    avatarColors: parseColors(row.avatarColors),
                    requestMessage: row.requestMessage ?? ""
                )
            }

            // In-app prompts: requests I sent that were accepted and not yet seen.
            await loadAcceptanceNotifications(uid: uid)
        } catch {
            print("⚠️ Contacts load failed: \(error)")
            contacts = SampleData.contacts
            friendRequests = SampleData.friendRequests
        }
    }

    // MARK: - Friends (search / send / respond)

    /// Searches existing platform users by email, @handle, or name via the
    /// `search_users` security function. Email is matched server-side but never
    /// returned. Includes my relationship to each result.
    @MainActor
    func searchUsers(query: String) async throws -> [SearchUserResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let results: [SearchUserResult] = try await supabase
            .rpc("search_users", params: SearchUsersParams(search_query: trimmed))
            .execute()
            .value
        // Don't surface users I've blocked in search.
        return results.filter { !blockedUserIds.contains($0.id) }
    }

    /// Loads the "Top Talent" creator directory via the `browse_top_talent`
    /// security function. Returns the same SearchUserResult shape as searchUsers
    /// (so the directory reuses the same row + add-friend actions), ranked by
    /// follower count. Excludes me, anyone with Data Sharing off, and blocks.
    @MainActor
    func loadTopTalent(limit: Int = 50) async throws -> [SearchUserResult] {
        let results: [SearchUserResult] = try await supabase
            .rpc("browse_top_talent", params: BrowseTopTalentParams(limit_count: limit))
            .execute()
            .value
        return results.filter { !blockedUserIds.contains($0.id) }
    }

    // MARK: - Admin curation (every RPC is is_admin-gated server-side)

    /// Loads brands straight from the DB with NO SampleData fallback — the admin
    /// view must only show real, editable rows (featuring a sample brand that
    /// isn't in the table is a no-op).
    @MainActor
    func loadBrandsForAdmin() async throws -> [Brand] {
        let rows: [BrandRow] = try await supabase
            .from("brands").select().order("name", ascending: true).execute().value
        return rows.map { row in
            Brand(id: row.id, name: row.name, category: row.category ?? "",
                  tagline: row.tagline ?? "", symbol: row.symbol ?? "sparkles",
                  colors: parseColors(row.colors), activeCampaigns: row.activeCampaigns ?? 0,
                  featuredRank: row.featuredRank, iconUrl: row.iconUrl,
                  applicationCount: row.applicationCount ?? 0)
        }
    }

    /// Lists all users for the Top Talent curation screen, each with its current
    /// featured state. (Selecting featured_rank will fail loudly if the
    /// admin-curation migration hasn't been applied — which is the intent.)
    @MainActor
    func loadProfilesForCuration() async throws -> [ProfileCurationRow] {
        try await supabase
            .from("profiles")
            .select("id,name,handle,role,avatar_url,followers,featured_rank")
            .limit(500)
            .execute()
            .value
    }

    /// Lists currently-featured creators (with rank) for the curation screen.
    @MainActor
    func adminListFeaturedTalent() async throws -> [FeaturedTalentRow] {
        try await supabase
            .rpc("admin_list_featured_talent")
            .execute()
            .value
    }

    /// Feature / reorder / unfeature a creator in Top Talent. rank nil = unfeature.
    @MainActor
    func adminSetFeaturedTalent(userId: UUID, rank: Int?) async throws {
        try await supabase
            .rpc("admin_set_featured_talent", params: SetFeaturedTalentParams(target: userId.uuidString, rank: rank))
            .execute()
    }

    /// Feature / reorder / unfeature a brand.
    @MainActor
    func adminSetFeaturedBrand(brandId: UUID, rank: Int?) async throws {
        try await supabase
            .rpc("admin_set_featured_brand", params: SetFeaturedBrandParams(target: brandId.uuidString, rank: rank))
            .execute()
    }

    /// Create (id nil) or update a brand. Returns the brand id.
    @MainActor
    @discardableResult
    func adminUpsertBrand(id: UUID?, name: String, category: String?, tagline: String?,
                          symbol: String?, colors: String?, activeCampaigns: Int?, featuredRank: Int?,
                          iconUrl: String? = nil) async throws -> UUID {
        let newId: UUID = try await supabase
            .rpc("admin_upsert_brand", params: UpsertBrandParams(
                brand_id: id?.uuidString, p_name: name, p_category: category, p_tagline: tagline,
                p_symbol: symbol, p_colors: colors, p_active_campaigns: activeCampaigns, p_featured_rank: featuredRank,
                p_icon_url: iconUrl))
            .execute()
            .value
        return newId
    }

    @MainActor
    func adminDeleteBrand(id: UUID) async throws {
        try await supabase
            .rpc("admin_delete_brand", params: DeleteBrandParams(target: id.uuidString))
            .execute()
    }

    /// Loads campaigns straight from the DB with NO SampleData fallback — the admin
    /// view must only show real, editable rows (the public Discover read keeps its
    /// SampleData fallback; this curation read does not). Mirrors loadBrandsForAdmin.
    @MainActor
    func loadCampaignsForAdmin() async throws -> [Campaign] {
        let rows: [CampaignRow] = try await supabase
            .from("campaigns").select().order("created_at", ascending: false).execute().value
        return rows.map { row in
            Campaign(id: row.id, title: row.title, brand: row.brand, brandId: row.brandId,
                     budget: row.budget ?? "", tags: row.tags ?? [], deadline: row.deadline ?? "",
                     symbol: row.symbol ?? "sparkles", colors: parseColors(row.colors),
                     spotsLeft: row.spotsLeft ?? 0, description: row.description ?? "",
                     iconUrl: row.iconUrl, applicationCount: row.applicationCount ?? 0,
                     applied: row.applied ?? false)
        }
    }

    /// Create (id nil) or update a campaign. Returns the campaign id. Colors are sent
    /// as two decimal-UInt strings (color_a / color_b); the SQL combines them into the
    /// JSON `[a,b]` text the row decoder / parseColors expects. Mirrors adminUpsertBrand.
    @MainActor
    @discardableResult
    func adminUpsertCampaign(id: UUID?, title: String, brand: String?, budget: String?,
                             tags: [String]?, deadline: String?, symbol: String?,
                             colorA: String?, colorB: String?, spotsLeft: Int?,
                             iconUrl: String? = nil, description: String? = nil,
                             brandId: UUID? = nil) async throws -> UUID {
        let newId: UUID = try await supabase
            .rpc("admin_upsert_campaign", params: UpsertCampaignParams(
                campaign_id: id?.uuidString, p_title: title, p_brand: brand, p_budget: budget,
                p_tags: tags, p_deadline: deadline, p_symbol: symbol,
                p_color_a: colorA, p_color_b: colorB, p_spots_left: spotsLeft,
                p_icon_url: iconUrl, p_description: description, p_brand_id: brandId?.uuidString))
            .execute()
            .value
        return newId
    }

    @MainActor
    func adminDeleteCampaign(id: UUID) async throws {
        try await supabase
            .rpc("admin_delete_campaign", params: DeleteCampaignParams(target: id.uuidString))
            .execute()
    }

    /// Grants (makeAdmin true) or revokes (makeAdmin false) the is_admin flag on
    /// another user. The server is_admin-gates the call and blocks changing your
    /// own status. Mirrors adminDeleteBrand. Callers refresh their user list after.
    @MainActor
    func adminSetAdmin(targetId: UUID, makeAdmin: Bool) async throws {
        try await supabase
            .rpc("admin_set_admin", params: SetAdminParams(target: targetId.uuidString, make_admin: makeAdmin))
            .execute()
    }

    /// Sends a friend request (pure DB, no email). Returns the server status:
    /// "sent", "already_sent", "already_friends", or "incoming_exists".
    @MainActor
    func sendFriendRequest(to targetId: UUID, message: String) async throws -> String {
        let status: String = try await supabase
            .rpc("send_friend_request", params: SendFriendRequestParams(
                target_id: targetId.uuidString,
                message: message
            ))
            .execute()
            .value
        return status
    }

    /// Accepts or rejects a received request. On accept the server creates the
    /// bidirectional friendship atomically. Returns the resulting status.
    @MainActor
    @discardableResult
    func respondToFriendRequest(requestId: UUID, accept: Bool) async throws -> String {
        let status: String = try await supabase
            .rpc("respond_friend_request", params: RespondFriendRequestParams(
                request_id: requestId.uuidString,
                accept: accept
            ))
            .execute()
            .value
        return status
    }

    /// Removes a friend in both directions atomically via the `remove_friend`
    /// SECURITY DEFINER function (the friendships DELETE RLS policy alone can only
    /// remove my own side). Refreshes the contact list + count on success.
    @MainActor
    func removeFriend(friendId: UUID) async throws {
        let _: String = try await supabase
            .rpc("remove_friend", params: RemoveFriendParams(target_id: friendId.uuidString))
            .execute()
            .value
        await loadContacts()
    }

    /// Loads the names of people who accepted a request I sent (unseen).
    @MainActor
    private func loadAcceptanceNotifications(uid: UUID) async {
        do {
            let rows: [FriendRequestDBRow] = try await supabase
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: uid.uuidString)
                .eq("status", value: "accepted")
                .eq("seen_by_sender", value: false)
                .execute()
                .value
            guard !rows.isEmpty else { friendAcceptedNames = []; return }

            // The accepter is `to_user_id` — fetch their display names.
            let accepterIds = rows.map { $0.toUserId.uuidString }
            let profs: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: accepterIds)
                .execute()
                .value
            let nameById = Dictionary(
                profs.map { ($0.id, $0.name ?? $0.handle ?? "Someone") },
                uniquingKeysWith: { first, _ in first }
            )
            friendAcceptedNames = rows.compactMap { nameById[$0.toUserId] }
        } catch {
            print("⚠️ Acceptance notifications load failed: \(error)")
            friendAcceptedNames = []
        }
    }

    /// Marks all of my accepted requests as seen, clearing the in-app prompt.
    @MainActor
    func markAcceptancesSeen() async {
        guard let uid = userId else { return }
        friendAcceptedNames = []
        do {
            try await supabase
                .from("friend_requests")
                .update(SeenBySenderUpdate(seen_by_sender: true))
                .eq("from_user_id", value: uid.uuidString)
                .eq("status", value: "accepted")
                .eq("seen_by_sender", value: false)
                .execute()
        } catch {
            print("⚠️ Mark acceptances seen failed: \(error)")
        }
    }

    /// Maps a friend's profile into the Contact model used by the UI. Profiles
    /// have no avatar palette, so we derive a stable gradient from their id.
    private func contact(from p: ProfileRow) -> Contact {
        Contact(
            id: p.id,
            name: p.name ?? p.handle ?? "User",
            handle: p.handle ?? "",
            role: p.role ?? "",
            platform: "",
            followers: p.followers ?? "0",
            avatarColors: Self.avatarPalette(for: p.id),
            isOnline: false,
            avatarUrl: p.avatarUrl
        )
    }

    /// Deterministic two-color gradient chosen from a fixed palette by user id,
    /// so each friend keeps a consistent look across sessions.
    /// Two-letter initials for an avatar, derived from a display name.
    nonisolated static func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    // Formatters are expensive to build, so cache one configured instance each
    // instead of allocating a fresh DateFormatter on every (very frequent) call.
    // `nonisolated(unsafe)` is safe here: each is configured once and only ever
    // read (DateFormatter is documented thread-safe for concurrent formatting).
    nonisolated(unsafe) private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    nonisolated(unsafe) private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    nonisolated(unsafe) private static let yearMonthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMd")
        return f
    }()

    nonisolated(unsafe) private static let yesterdayFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named
        return f
    }()

    /// Short clock time (locale-aware, e.g. "9:05 AM" or "21:05") for a message.
    nonisolated static func clockTime(from date: Date?) -> String {
        guard let date else { return "" }
        return clockFormatter.string(from: date)
    }

    /// Decides whether a "file" message is actually a voice clip. The MIME is the
    /// primary signal but it can be missing or odd (the message_type CHECK has no
    /// "audio"), so we also recognize the canonical "voice.m4a" name and any common
    /// audio file extension.
    nonisolated static func isVoiceFile(mime: String?, name: String?) -> Bool {
        if mime?.hasPrefix("audio") == true { return true }
        guard let lower = name?.lowercased() else { return false }
        if lower == "voice.m4a" { return true }
        let audioExtensions = [".m4a", ".mp3", ".aac", ".wav", ".ogg"]
        return audioExtensions.contains { lower.hasSuffix($0) }
    }

    /// Relative time for the conversation list: clock time today, "Yesterday",
    /// or a localized short date for older messages.
    nonisolated static func relativeTime(from date: Date?) -> String {
        guard let date else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return clockTime(from: date)
        }
        if cal.isDateInYesterday(date) {
            return yesterdayFormatter.localizedString(for: cal.startOfDay(for: date), relativeTo: cal.startOfDay(for: Date()))
        }
        let sameYear = cal.isDate(date, equalTo: Date(), toGranularity: .year)
        return (sameYear ? monthDayFormatter : yearMonthDayFormatter).string(from: date)
    }

    nonisolated static func avatarPalette(for id: UUID) -> [UInt] {
        let palettes: [[UInt]] = [
            [0xFF4D6D, 0xFF9A5A],
            [0x7B2FF7, 0xF107A3],
            [0x2AF598, 0x009EFD],
            [0xFFB75E, 0xED8F03],
            [0x6C5CE7, 0xA29BFE],
            [0x00C6FB, 0x005BEA],
            [0xF953C6, 0xB91D73],
            [0x11998E, 0x38EF7D]
        ]
        let b = id.uuid
        let sum = UInt(b.0) &+ UInt(b.5) &+ UInt(b.7) &+ UInt(b.15)
        return palettes[Int(sum % UInt(palettes.count))]
    }

    // MARK: - Trust & Safety (block / report / terms)

    /// Refreshes the set of users I've blocked (`blocks.blocker_id = me`). Cheap —
    /// a small table — and called at bootstrap and on every contact reload so the
    /// in-memory set stays current for the conversation/group/search filters.
    @MainActor
    func loadBlocks() async {
        guard let uid = userId else { blockedUserIds = []; return }
        do {
            let rows: [BlockRow] = try await supabase
                .from("blocks")
                .select("blocked_id")
                .eq("blocker_id", value: uid.uuidString)
                .execute()
                .value
            blockedUserIds = Set(rows.map { $0.blockedId })
        } catch {
            print("⚠️ Load blocks failed: \(error)")
        }
    }

    /// Blocks a user: records the block, removes any friendship so they leave my
    /// contacts entirely, and refreshes contacts + conversations so they disappear
    /// immediately everywhere. Idempotent (upsert on the composite key).
    @MainActor
    func blockUser(_ otherId: UUID) async throws {
        guard let uid = userId else { throw DataError(message: "Not signed in") }
        try await supabase
            .from("blocks")
            .upsert(BlockInsert(blockerId: uid, blockedId: otherId))
            .execute()
        blockedUserIds.insert(otherId)
        // Best-effort: drop the friendship too (no-op / throws harmlessly if not friends).
        try? await removeFriend(friendId: otherId)
        await loadContacts()
        await loadConversations()
    }

    /// Removes a block. Refreshes contacts + conversations so the user can reappear.
    @MainActor
    func unblockUser(_ otherId: UUID) async throws {
        guard let uid = userId else { throw DataError(message: "Not signed in") }
        try await supabase
            .from("blocks")
            .delete()
            .eq("blocker_id", value: uid.uuidString)
            .eq("blocked_id", value: otherId.uuidString)
            .execute()
        blockedUserIds.remove(otherId)
        await loadContacts()
        await loadConversations()
    }

    /// Loads the profiles of users I've blocked, for the Blocked Accounts screen.
    @MainActor
    func loadBlockedContacts() async -> [Contact] {
        await loadBlocks()
        guard !blockedUserIds.isEmpty else { return [] }
        do {
            let profs: [ProfileRow] = try await supabase
                .from("profiles")
                .select()
                .in("id", values: blockedUserIds.map { $0.uuidString })
                .execute()
                .value
            return profs
                .map { contact(from: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("⚠️ Load blocked contacts failed: \(error)")
            return []
        }
    }

    /// Files a report against a user and/or a specific message. The excerpt is
    /// capped so a long message can't bloat the row. Reports land in `reports`
    /// for operator review + action (objectionable-content moderation pipeline).
    @MainActor
    func report(reportedUserId: UUID?, messageId: UUID? = nil, messageKind: String? = nil, excerpt: String? = nil, reason: String) async throws {
        guard let uid = userId else { throw DataError(message: "Not signed in") }
        try await supabase
            .from("reports")
            .insert(ReportInsert(
                reporterId: uid,
                reportedUserId: reportedUserId,
                messageId: messageId,
                messageKind: messageKind,
                contentExcerpt: excerpt.map { String($0.prefix(280)) },
                reason: reason
            ))
            .execute()
    }

    /// Stamps the EULA / Community Guidelines acceptance timestamp on my profile.
    /// Called once after a user signs up having agreed to the terms.
    @MainActor
    func acceptTerms() async {
        guard let uid = userId else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        do {
            try await supabase
                .from("profiles")
                .update(TermsAcceptedUpdate(terms_accepted_at: stamp))
                .eq("id", value: uid.uuidString)
                .execute()
        } catch {
            print("⚠️ Accept terms failed: \(error)")
        }
    }

    // MARK: - Direct Messages (1:1 chat)

    /// Total unread across all DM threads.
    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unread }
    }

    /// Total unread excluding muted conversations (免打扰) — drives the Chats tab
    /// badge so muted chats don't contribute to it.
    var unmutedUnread: Int {
        conversations.reduce(0) { $0 + (mutedIds.contains($1.id) ? 0 : $1.unread) }
    }

    /// Returns the existing (or freshly created) thread id for a 1:1 chat with a
    /// friend. The server rejects non-friends, so chat stays friends-only.
    @MainActor
    func getOrCreateThread(with otherId: UUID) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("get_or_create_thread", params: GetOrCreateThreadParams(p_other: otherId.uuidString))
            .execute()
            .value
        guard let threadId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid thread id")
        }
        return threadId
    }

    /// Sends a DM via the friend-validated `send_dm` function (pure DB — never any
    /// email). Refreshes the conversation list so the preview, unread count, and
    /// tab badge stay correct. Returns the thread id.
    @MainActor
    @discardableResult
    func sendMessage(to otherId: UUID, body: String, replyTo: UUID? = nil) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("send_dm", params: SendDMParams(
                p_other: otherId.uuidString,
                p_body: body,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
        guard let threadId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid thread id")
        }
        return threadId
    }

    /// Result of uploading a chat image: the private storage path plus pixel size.
    struct ChatImageUpload: Sendable { let path: String; let width: Int; let height: Int }

    /// Compresses + uploads an image into the private `chat-media` bucket under
    /// `{threadId}/{uuid}.jpg`. Storage RLS only lets the two thread participants
    /// write here. Returns the path (stored in `dm_messages.image_url`) + dimensions.
    @MainActor
    func uploadChatImage(threadId: UUID, imageData: Data) async throws -> ChatImageUpload {
        let compressed = Self.compressedJPEG(imageData, maxDimension: 1280, quality: 0.8) ?? imageData
        let dims = Self.pixelSize(compressed) ?? (width: 1, height: 1)
        let folder = threadId.uuidString.lowercased()
        let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage
            .from("chat-media")
            .upload(path, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: false))
        return ChatImageUpload(path: path, width: dims.width, height: dims.height)
    }

    /// Sends an image message via the friend-validated `send_dm_media` function.
    /// Pure DB — never any email. Refreshes the conversation list afterwards.
    @MainActor
    @discardableResult
    func sendImageMessage(to otherId: UUID, imagePath: String, caption: String, width: Int, height: Int, replyTo: UUID? = nil) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("send_dm_media", params: SendDMMediaParams(
                p_other: otherId.uuidString,
                p_image_url: imagePath,
                p_caption: caption,
                p_width: width,
                p_height: height,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
        guard let threadId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid thread id")
        }
        return threadId
    }

    /// Result of uploading a chat file: the private storage path + original name/size/mime.
    struct ChatFileUpload: Sendable { let path: String; let fileName: String; let fileSize: Int; let mime: String }

    /// Uploads an arbitrary document into the private `chat-media` bucket under
    /// `{threadId}/{uuid}.{ext}` — the same thread-scoped Storage RLS as images,
    /// so only the two participants can read/write. No compression (docs must stay
    /// byte-exact). Returns the stored path plus name/size/mime for the file bubble.
    @MainActor
    func uploadChatFile(threadId: UUID, data: Data, fileName: String, mimeType: String) async throws -> ChatFileUpload {
        let folder = threadId.uuidString.lowercased()
        let ext = (fileName as NSString).pathExtension.lowercased()
        let object = ext.isEmpty
            ? UUID().uuidString.lowercased()
            : "\(UUID().uuidString.lowercased()).\(ext)"
        let path = "\(folder)/\(object)"
        try await supabase.storage
            .from("chat-media")
            .upload(path, data: data, options: FileOptions(contentType: mimeType, upsert: false))
        return ChatFileUpload(path: path, fileName: fileName, fileSize: data.count, mime: mimeType)
    }

    /// Sends a file message via the generic friend-validated `send_dm_attachment`
    /// function (leaves send_dm / send_dm_media untouched). Refreshes the inbox.
    @MainActor
    @discardableResult
    func sendFileMessage(to otherId: UUID, upload: ChatFileUpload, replyTo: UUID? = nil) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("send_dm_attachment", params: SendDMAttachmentParams(
                p_other: otherId.uuidString,
                p_type: "file",
                p_path: upload.path,
                p_caption: "",
                p_file_name: upload.fileName,
                p_file_size: upload.fileSize,
                p_file_mime: upload.mime,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
        guard let threadId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid thread id")
        }
        return threadId
    }

    /// Sends a previously-uploaded video as a 1:1 video message (reuses the file
    /// upload; only the attachment `p_type` is "video").
    @MainActor
    @discardableResult
    func sendVideoMessage(to otherId: UUID, upload: ChatFileUpload, replyTo: UUID? = nil) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("send_dm_attachment", params: SendDMAttachmentParams(
                p_other: otherId.uuidString,
                p_type: "video",
                p_path: upload.path,
                p_caption: "",
                p_file_name: upload.fileName,
                p_file_size: upload.fileSize,
                p_file_mime: upload.mime,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
        guard let threadId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid thread id")
        }
        return threadId
    }

    /// Uploads a voice recording into the private `chat-media` bucket under
    /// `{threadId}/{uuid}.m4a` — the same thread-scoped Storage RLS as images/files,
    /// so only the two participants can read/write. No compression (the AAC clip is
    /// already small). Returns the stored path (kept in `dm_messages.image_url`).
    @MainActor
    func uploadChatAudio(threadId: UUID, data: Data) async throws -> String {
        let folder = threadId.uuidString.lowercased()
        let path = "\(folder)/\(UUID().uuidString.lowercased()).m4a"
        try await supabase.storage
            .from("chat-media")
            .upload(path, data: data, options: FileOptions(contentType: "audio/m4a", upsert: false))
        return path
    }

    /// Uploads a voice recording then sends it as an audio message via the generic
    /// friend-validated `send_dm_attachment` function (p_type "audio"). Refreshes
    /// the inbox afterwards.
    @MainActor
    func sendVoiceMessage(to otherId: UUID, threadId: UUID, data: Data) async throws {
        let path = try await uploadChatAudio(threadId: threadId, data: data)
        let _: String = try await supabase
            .rpc("send_dm_attachment", params: SendDMAttachmentParams(
                p_other: otherId.uuidString,
                // Sent as "file" with an audio MIME — the message_type CHECK only
                // allows text/image/video/file. Decoded back to .audio by MIME on load.
                p_type: "file",
                p_path: path,
                p_caption: "",
                p_file_name: "voice.m4a",
                p_file_size: data.count,
                p_file_mime: "audio/m4a",
                p_reply_to: nil
            ))
            .execute()
            .value
        await loadConversations()
    }

    /// Short-lived signed URLs for private chat images, cached by path so the
    /// realtime-driven reloads don't re-sign the same image on every insert.
    private var signedURLCache: [String: (url: URL, expires: Date)] = [:]

    @MainActor
    func signedChatImageURL(path: String) async throws -> URL {
        if let cached = signedURLCache[path], cached.expires > Date().addingTimeInterval(120) {
            return cached.url
        }
        let url = try await supabase.storage
            .from("chat-media")
            .createSignedURL(path: path, expiresIn: 3600)
        signedURLCache[path] = (url, Date().addingTimeInterval(3600))
        return url
    }

    // MARK: - On-device media cache
    //
    // Download a chat-media object ONCE (keyed by its stable storage path) and
    // reuse the local copy, so re-viewing it costs no bandwidth. The signed URL
    // rotates hourly, so caching by URL (what AsyncImage does) re-downloads every
    // hour — caching by path avoids that. Lives in the Caches directory, which the
    // OS may reclaim under storage pressure.

    private static let mediaCacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("wf-media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func mediaCacheFile(path: String, ext: String) -> URL {
        let safe = path.replacingOccurrences(of: "[^A-Za-z0-9]", with: "_", options: .regularExpression)
        return mediaCacheDir.appendingPathComponent("\(safe).\(ext)")
    }

    /// A chat image from the on-device cache: downloaded once (keyed by its stable
    /// storage `path`) and reused from memory/disk. Returns nil on failure.
    @MainActor
    func cachedChatImage(path: String) async -> UIImage? {
        let key = path as NSString
        if let mem = imageMemoryCache.object(forKey: key) { return mem }
        let file = Self.mediaCacheFile(path: path, ext: "img")
        if let data = try? Data(contentsOf: file), let img = UIImage(data: data) {
            imageMemoryCache.setObject(img, forKey: key)
            return img
        }
        do {
            let url = try await signedChatImageURL(path: path)
            let (data, _) = try await URLSession.shared.data(from: url)
            try? data.write(to: file, options: .atomic)
            guard let img = UIImage(data: data) else { return nil }
            imageMemoryCache.setObject(img, forKey: key)
            return img
        } catch {
            print("⚠️ cachedChatImage failed: \(error)")
            return nil
        }
    }

    /// Removes the on-disk media cache (called on sign-out, for privacy + space).
    static func clearMediaCache() {
        try? FileManager.default.removeItem(at: mediaCacheDir)
        try? FileManager.default.createDirectory(at: mediaCacheDir, withIntermediateDirectories: true)
    }

    /// Local `file://` url for a chat-media object (e.g. a video), downloaded once
    /// to the on-device cache and reused — so re-watching costs no bandwidth. The
    /// hourly signed URL is only used for that first download.
    @MainActor
    func cachedMediaFileURL(path: String, ext: String = "mp4") async throws -> URL {
        let file = Self.mediaCacheFile(path: path, ext: ext)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let url = try await signedChatImageURL(path: path)
        let (tmp, _) = try await URLSession.shared.download(from: url)
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: tmp, to: file)
        return file
    }

    // MARK: - Account deletion

    private struct DeleteAccountResponse: Decodable { let ok: Bool?; let success: Bool?; let error: String? }

    /// Permanently deletes the signed-in user's account via the `delete-account`
    /// edge function (App Store 5.1.1(v) requirement). The caller signs out after.
    @MainActor
    func deleteAccount() async throws {
        let _: DeleteAccountResponse = try await supabase.functions.invoke(
            "delete-account",
            options: .init()
        )
    }

    /// Loads all messages in a thread (RLS limits this to the two participants),
    /// mapped to the UI `ChatMessage` model. Filters out messages the user has
    /// soft-deleted and those before the clear watermark; marks recalled messages
    /// with `.recalled` kind so the UI shows a placeholder.
    @MainActor
    func loadThreadMessages(threadId: UUID) async -> [ChatMessage] {
        guard let uid = userId else { return [] }
        do {
            async let rowsTask: [DMMessageRow] = supabase
                .from("dm_messages")
                .select()
                .eq("thread_id", value: threadId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            async let deletionsTask: [MessageDeletionRow] = supabase
                .from("message_deletions")
                .select("message_id,kind")
                .eq("user_id", value: uid.uuidString)
                .eq("kind", value: "dm")
                .execute()
                .value
            async let clearTask: [DMClearRow] = supabase
                .from("dm_clears")
                .select("thread_id,cleared_before")
                .eq("user_id", value: uid.uuidString)
                .eq("thread_id", value: threadId.uuidString)
                .execute()
                .value

            let rows = try await rowsTask
            let deletions = try await deletionsTask
            let clears = try await clearTask

            let deletedSet = Set(deletions.map { $0.messageId })
            let clearedBefore = clears.first?.clearedBefore

            return rows.compactMap { row in
                // Skip messages I've soft-deleted (A) or that are before my clear watermark (C)
                if deletedSet.contains(row.id) { return nil }
                if let threshold = clearedBefore, let createdAt = row.createdAt, createdAt <= threshold { return nil }

                let isRecalled = row.recalledAt != nil
                let kind: ChatMessageKind
                if isRecalled {
                    kind = .text  // recalled placeholder uses text rendering
                } else {
                    switch row.messageType ?? "text" {
                    case "image": kind = .image
                    case "video": kind = .video
                    case "audio": kind = .audio
                    // Voice clips are stored as "file" with an audio MIME (the
                    // message_type CHECK has no "audio") — surface them as voice.
                    // Harden the detection: the MIME can be missing or odd, so also
                    // treat a "voice.m4a" name or any audio-extension file as audio.
                    case "file": kind = Self.isVoiceFile(mime: row.fileMime, name: row.fileName) ? .audio : .file
                    default: kind = .text
                    }
                }
                return ChatMessage(
                    id: row.id,
                    text: isRecalled ? "" : row.body,
                    sender: row.senderId == uid ? .me : .them,
                    time: Self.clockTime(from: row.createdAt),
                    kind: kind,
                    imagePath: isRecalled ? nil : row.imageUrl,
                    imageWidth: isRecalled ? nil : row.imageWidth,
                    imageHeight: isRecalled ? nil : row.imageHeight,
                    fileName: isRecalled ? nil : row.fileName,
                    fileSize: isRecalled ? nil : row.fileSize,
                    fileMime: isRecalled ? nil : row.fileMime,
                    readAt: row.readAt,
                    replyTo: row.replyToMessageId,
                    isRecalled: isRecalled,
                    senderId: row.senderId,
                    createdAt: row.createdAt
                )
            }
        } catch {
            print("⚠️ Load thread messages failed: \(error)")
            return []
        }
    }

    /// Marks messages addressed to me in this thread as read (server-side only
    /// touches rows where recipient_id = me).
    @MainActor
    func markThreadRead(threadId: UUID) async {
        do {
            _ = try await supabase
                .rpc("mark_thread_read", params: MarkThreadReadParams(p_thread: threadId.uuidString))
                .execute()
        } catch {
            print("⚠️ mark_thread_read failed: \(error)")
        }
    }

    /// Keeps the conversation list + tab badge live. Runs until the calling task
    /// is cancelled — tie this to a long-lived view's `.task` (RootTabView). RLS
    /// scopes delivered inserts to threads/groups I'm part of, so any new message
    /// (DM or group, incoming or my own) refreshes the inbox.
    @MainActor
    func observeInbox() async {
        guard let uid = userId else { return }
        let channel = supabase.channel("inbox-\(uid.uuidString)")
        let dmInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "dm_messages")
        let groupInserts = channel.postgresChange(InsertAction.self, schema: "public", table: "group_messages")
        // UPDATE events propagate recalls so the inbox preview flips to 「已撤回」 in real time.
        let dmUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "dm_messages")
        let groupUpdates = channel.postgresChange(UpdateAction.self, schema: "public", table: "group_messages")
        await channel.subscribe()
        defer {
            let ch = channel
            Task { await ch.unsubscribe(); await supabase.removeChannel(ch) }
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in dmInserts { await self?.loadConversations() }
            }
            group.addTask { [weak self] in
                for await _ in groupInserts { await self?.loadConversations() }
            }
            group.addTask { [weak self] in
                for await _ in dmUpdates { await self?.loadConversations() }
            }
            group.addTask { [weak self] in
                for await _ in groupUpdates { await self?.loadConversations() }
            }
        }
    }

    // MARK: - Group Chat

    /// Creates a group atomically via the friend-validated `create_group` function:
    /// the server adds me as admin + each selected friend as a member, validates
    /// every member with `are_friends`, and rolls back entirely on failure (never a
    /// half-empty group). Refreshes the inbox and returns the new group id.
    @MainActor
    func createGroup(name: String, memberIds: [UUID]) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("create_group", params: CreateGroupParams(
                p_name: name,
                p_member_ids: memberIds.map { $0.uuidString }
            ))
            .execute()
            .value
        await loadConversations()
        guard let groupId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid group id")
        }
        return groupId
    }

    /// Loads all messages in a group (RLS limits this to members), each with its
    /// sender's profile embedded so incoming bubbles can show the sender's avatar +
    /// name. Filters out messages the user has soft-deleted and those before the
    /// clear watermark; marks recalled messages with `.recalled` kind.
    @MainActor
    func loadGroupMessages(groupId: UUID) async -> [GroupChatMessage] {
        guard let uid = userId else { return [] }
        do {
            async let rowsTask: [GroupMessageRow] = supabase
                .from("group_messages")
                .select("id,group_id,sender_id,body,message_type,image_url,image_width,image_height,file_name,file_size,file_mime,created_at,reply_to_message_id,recalled_at,recalled_by,sender:profiles!group_messages_sender_id_fkey(id,name,handle,avatar_url)")
                .eq("group_id", value: groupId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            async let deletionsTask: [MessageDeletionRow] = supabase
                .from("message_deletions")
                .select("message_id,kind")
                .eq("user_id", value: uid.uuidString)
                .eq("kind", value: "group")
                .execute()
                .value
            async let clearTask: [GroupClearRow] = supabase
                .from("group_clears")
                .select("group_id,cleared_before")
                .eq("user_id", value: uid.uuidString)
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value

            let rows = try await rowsTask
            let deletions = try await deletionsTask
            let clears = try await clearTask

            let deletedSet = Set(deletions.map { $0.messageId })
            let clearedBefore = clears.first?.clearedBefore

            return rows.compactMap { row in
                if deletedSet.contains(row.id) { return nil }
                if let threshold = clearedBefore, let createdAt = row.createdAt, createdAt <= threshold { return nil }
                // Hide messages from users I've blocked.
                if blockedUserIds.contains(row.senderId) { return nil }

                let name = row.sender?.name ?? row.sender?.handle ?? "User"
                let isRecalled = row.recalledAt != nil
                let kind: ChatMessageKind
                if isRecalled {
                    kind = .text
                } else {
                    switch row.messageType ?? "text" {
                    case "image": kind = .image
                    case "video": kind = .video
                    case "audio": kind = .audio
                    // Voice clips are stored as "file" with an audio MIME (the
                    // message_type CHECK has no "audio") — surface them as voice.
                    // Harden the detection: the MIME can be missing or odd, so also
                    // treat a "voice.m4a" name or any audio-extension file as audio.
                    case "file": kind = Self.isVoiceFile(mime: row.fileMime, name: row.fileName) ? .audio : .file
                    default: kind = .text
                    }
                }
                return GroupChatMessage(
                    id: row.id,
                    text: isRecalled ? "" : row.body,
                    sender: row.senderId == uid ? .me : .them,
                    senderId: row.senderId,
                    senderName: name,
                    senderColors: Self.avatarPalette(for: row.senderId),
                    senderAvatarUrl: row.sender?.avatarUrl,
                    time: Self.clockTime(from: row.createdAt),
                    kind: kind,
                    imagePath: isRecalled ? nil : row.imageUrl,
                    imageWidth: isRecalled ? nil : row.imageWidth,
                    imageHeight: isRecalled ? nil : row.imageHeight,
                    fileName: isRecalled ? nil : row.fileName,
                    fileSize: isRecalled ? nil : row.fileSize,
                    fileMime: isRecalled ? nil : row.fileMime,
                    isRecalled: isRecalled,
                    createdAt: row.createdAt,
                    replyTo: isRecalled ? nil : row.replyToMessageId
                )
            }
        } catch {
            print("⚠️ Load group messages failed: \(error)")
            return []
        }
    }

    /// Sends a group message via the member-validated `send_group_message` function
    /// (text only for now). Refreshes the inbox so the preview/unread/badge stay
    /// correct. The list re-reads from the DB — never a fake local append.
    @MainActor
    func sendGroupMessage(groupId: UUID, body: String, replyTo: UUID? = nil) async throws {
        let _: String = try await supabase
            .rpc("send_group_message", params: SendGroupMessageParams(
                p_group: groupId.uuidString,
                p_body: body,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
    }

    /// Compresses + uploads an image into the private `chat-media` bucket under
    /// `{groupId}/{uuid}.jpg`. The group-member Storage RLS lets any member read/write
    /// here (mirrors the DM thread-scoped path). Returns the path + pixel dimensions.
    @MainActor
    func uploadGroupImage(groupId: UUID, imageData: Data) async throws -> ChatImageUpload {
        let compressed = Self.compressedJPEG(imageData, maxDimension: 1280, quality: 0.8) ?? imageData
        let dims = Self.pixelSize(compressed) ?? (width: 1, height: 1)
        let folder = groupId.uuidString.lowercased()
        let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage
            .from("chat-media")
            .upload(path, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: false))
        return ChatImageUpload(path: path, width: dims.width, height: dims.height)
    }

    /// Uploads an arbitrary document into the private `chat-media` bucket under
    /// `{groupId}/{uuid}.{ext}` — the same group-scoped Storage RLS as group images.
    /// No compression (docs stay byte-exact). Returns the path + name/size/mime.
    @MainActor
    func uploadGroupFile(groupId: UUID, data: Data, fileName: String, mimeType: String) async throws -> ChatFileUpload {
        let folder = groupId.uuidString.lowercased()
        let ext = (fileName as NSString).pathExtension.lowercased()
        let object = ext.isEmpty
            ? UUID().uuidString.lowercased()
            : "\(UUID().uuidString.lowercased()).\(ext)"
        let path = "\(folder)/\(object)"
        try await supabase.storage
            .from("chat-media")
            .upload(path, data: data, options: FileOptions(contentType: mimeType, upsert: false))
        return ChatFileUpload(path: path, fileName: fileName, fileSize: data.count, mime: mimeType)
    }

    /// Sends a group image via the member-validated `send_group_attachment`
    /// (type=image). Refreshes the inbox so the preview/unread/badge stay correct.
    @MainActor
    func sendGroupImageMessage(groupId: UUID, imagePath: String, caption: String, width: Int, height: Int, replyTo: UUID? = nil) async throws {
        let _: String = try await supabase
            .rpc("send_group_attachment", params: SendGroupAttachmentParams(
                p_group: groupId.uuidString,
                p_type: "image",
                p_path: imagePath,
                p_caption: caption,
                p_file_name: nil,
                p_file_size: nil,
                p_file_mime: nil,
                p_width: width,
                p_height: height,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
    }

    /// Sends a group file via the member-validated `send_group_attachment`
    /// (type=file). Refreshes the inbox afterwards.
    @MainActor
    func sendGroupFileMessage(groupId: UUID, upload: ChatFileUpload, replyTo: UUID? = nil) async throws {
        let _: String = try await supabase
            .rpc("send_group_attachment", params: SendGroupAttachmentParams(
                p_group: groupId.uuidString,
                p_type: "file",
                p_path: upload.path,
                p_caption: "",
                p_file_name: upload.fileName,
                p_file_size: upload.fileSize,
                p_file_mime: upload.mime,
                p_width: nil,
                p_height: nil,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
    }

    /// Sends a previously-uploaded video into a group (reuses the file upload; only
    /// the attachment `p_type` is "video").
    @MainActor
    func sendGroupVideoMessage(groupId: UUID, upload: ChatFileUpload, replyTo: UUID? = nil) async throws {
        let _: String = try await supabase
            .rpc("send_group_attachment", params: SendGroupAttachmentParams(
                p_group: groupId.uuidString,
                p_type: "video",
                p_path: upload.path,
                p_caption: "",
                p_file_name: upload.fileName,
                p_file_size: upload.fileSize,
                p_file_mime: upload.mime,
                p_width: nil,
                p_height: nil,
                p_reply_to: replyTo?.uuidString
            ))
            .execute()
            .value
        await loadConversations()
    }

    /// Uploads a voice recording into the private `chat-media` bucket under
    /// `{groupId}/{uuid}.m4a` — the same group-scoped Storage RLS as group images.
    /// No compression (the AAC clip is already small). Returns the stored path.
    @MainActor
    func uploadGroupAudio(groupId: UUID, data: Data) async throws -> String {
        let folder = groupId.uuidString.lowercased()
        let path = "\(folder)/\(UUID().uuidString.lowercased()).m4a"
        try await supabase.storage
            .from("chat-media")
            .upload(path, data: data, options: FileOptions(contentType: "audio/m4a", upsert: false))
        return path
    }

    /// Uploads a voice recording then sends it as a group audio message via the
    /// member-validated `send_group_attachment` (type=audio). Refreshes the inbox.
    @MainActor
    func sendGroupVoice(groupId: UUID, data: Data) async throws {
        let path = try await uploadGroupAudio(groupId: groupId, data: data)
        let _: String = try await supabase
            .rpc("send_group_attachment", params: SendGroupAttachmentParams(
                p_group: groupId.uuidString,
                // Sent as "file" with an audio MIME — message_type only allows
                // text/image/video/file. Decoded back to .audio by MIME on load.
                p_type: "file",
                p_path: path,
                p_caption: "",
                p_file_name: "voice.m4a",
                p_file_size: data.count,
                p_file_mime: "audio/m4a",
                p_width: nil,
                p_height: nil,
                p_reply_to: nil
            ))
            .execute()
            .value
        await loadConversations()
    }

    /// Marks the group read up to now (clears my unread count) via `mark_group_read`.
    @MainActor
    func markGroupRead(groupId: UUID) async {
        do {
            _ = try await supabase
                .rpc("mark_group_read", params: MarkGroupReadParams(p_group: groupId.uuidString))
                .execute()
        } catch {
            print("⚠️ mark_group_read failed: \(error)")
        }
    }

    // MARK: - Group Settings

    /// Loads the group's member roster (member-only) via `list_group_members`:
    /// each member's profile + role + an owner flag, owner sorted first.
    @MainActor
    func listGroupMembers(groupId: UUID) async throws -> [GroupMember] {
        let rows: [GroupMemberRow] = try await supabase
            .rpc("list_group_members", params: GroupIdParam(p_group: groupId.uuidString))
            .execute()
            .value
        return rows.map { row in
            GroupMember(
                id: row.userId,
                name: row.name ?? row.handle ?? "User",
                handle: row.handle ?? "",
                avatarUrl: row.avatarUrl,
                role: row.role,
                isOwner: row.isOwner
            )
        }
    }

    /// Renames the group via the owner-only `group_rename` function. Refreshes the
    /// inbox so the new name shows in the conversation list. Throws on failure
    /// (e.g. not the owner) so the caller can surface a real error.
    @MainActor
    func renameGroup(groupId: UUID, name: String) async throws {
        _ = try await supabase
            .rpc("group_rename", params: GroupRenameParams(p_group: groupId.uuidString, p_name: name))
            .execute()
        await loadConversations()
    }

    /// Invites a friend into the group via `group_add_member` (any member may
    /// invite, but only their own friend). Throws on failure (not a member /
    /// not friends) so the caller can surface a real error.
    @MainActor
    func addGroupMember(groupId: UUID, userId: UUID) async throws {
        _ = try await supabase
            .rpc("group_add_member", params: GroupMemberParams(p_group: groupId.uuidString, p_user: userId.uuidString))
            .execute()
    }

    /// Removes a member via the owner-only `group_remove_member` (the owner can
    /// never be removed). Throws on failure so the caller can surface an error.
    @MainActor
    func removeGroupMember(groupId: UUID, userId: UUID) async throws {
        _ = try await supabase
            .rpc("group_remove_member", params: GroupMemberParams(p_group: groupId.uuidString, p_user: userId.uuidString))
            .execute()
    }

    /// Uploads a new group avatar to the public `avatars` bucket and stamps its
    /// public URL onto the `group_threads` row via the owner-gated `group_set_avatar`
    /// RPC. A direct table UPDATE is silently rejected by RLS, so the DB write goes
    /// through the SECURITY DEFINER function (owner-only) instead. Refreshes the
    /// inbox so the new photo shows in the conversation list. Returns the new URL.
    @MainActor
    @discardableResult
    func changeGroupAvatar(groupId: UUID, imageData: Data) async throws -> String {
        let compressed = Self.compressedJPEG(imageData, maxDimension: 512, quality: 0.82) ?? imageData
        let folder = groupId.uuidString.lowercased()
        let filePath = "\(folder)/group-\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage
            .from("avatars")
            .upload(filePath, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        let url = publicURL.absoluteString
        try await supabase
            .rpc("group_set_avatar", params: GroupSetAvatarParams(p_group: groupId.uuidString, p_url: url))
            .execute()
        await loadConversations()
        return url
    }

    /// Leaves the group by deleting my own `group_members` row (any member). The
    /// DELETE RLS policy only lets me remove my own membership, so this can't evict
    /// anyone else. Refreshes the inbox so the group disappears from my list.
    @MainActor
    func leaveGroup(groupId: UUID) async throws {
        guard let uid = userId else { throw DataError(message: "Not signed in") }
        try await supabase
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("user_id", value: uid.uuidString)
            .execute()
        await loadConversations()
    }

    /// Dissolves the group by deleting the `group_threads` row (owner-only — the
    /// DELETE RLS policy rejects non-owners). Cascades remove the members + messages.
    /// Refreshes the inbox so the group disappears for everyone.
    @MainActor
    func dissolveGroup(groupId: UUID) async throws {
        try await supabase
            .from("group_threads")
            .delete()
            .eq("id", value: groupId.uuidString)
            .execute()
        await loadConversations()
    }

    // MARK: - Delete / Recall / Clear Chat

    /// Soft-deletes a single message for the caller only (A: local-only).
    @MainActor
    func deleteMessageForMe(messageId: UUID, kind: String) async throws {
        _ = try await supabase
            .rpc("delete_message_for_me", params: DeleteMessageParams(p_message_id: messageId.uuidString, p_kind: kind))
            .execute()
    }

    /// Recalls a message for everyone (B: bidirectional). Only the sender can
    /// recall their own message within 2 minutes.
    @MainActor
    func recallMessage(messageId: UUID, kind: String) async throws {
        _ = try await supabase
            .rpc("recall_message", params: RecallMessageParams(p_message_id: messageId.uuidString, p_kind: kind))
            .execute()
    }

    /// Clears all messages in a DM thread for the caller only (C: local-only).
    @MainActor
    func clearDMHistory(threadId: UUID) async throws {
        _ = try await supabase
            .rpc("clear_dm_history", params: ClearDMHistoryParams(p_thread_id: threadId.uuidString))
            .execute()
        await loadConversations()
    }

    /// Clears all messages in a group for the caller only (C: local-only).
    @MainActor
    func clearGroupHistory(groupId: UUID) async throws {
        _ = try await supabase
            .rpc("clear_group_history", params: ClearGroupHistoryParams(p_group_id: groupId.uuidString))
            .execute()
        await loadConversations()
    }

    /// Hides a conversation from my chat list (swipe-to-delete). Calls the
    /// `hide_conversation` RPC which clears my history + marks it hidden.
    /// The conversation reappears automatically when a new message arrives
    /// after the hide time. Refreshes the inbox afterwards.
    @MainActor
    func hideConversation(conversationId: UUID, type: String) async throws {
        _ = try await supabase
            .rpc("hide_conversation", params: HideConversationParams(
                p_conversation_id: conversationId.uuidString,
                p_conversation_type: type
            ))
            .execute()
        await loadConversations()
    }

    // MARK: - Forward Message

    /// Forwards a message to one or more conversations via the `forward-message`
    /// edge function, which does the server-side `storage.copy` (media is reused,
    /// never re-uploaded) + dual permission checks (source read + target write),
    /// then sends through the existing send functions. Refreshes the inbox.
    /// Throws if nothing was forwarded so the caller can show an error.
    @MainActor
    func forwardMessage(source: ForwardSource, friendIds: [UUID], groupIds: [UUID]) async throws {
        let targets = friendIds.map { ForwardTargetParam(kind: "friend", id: $0.uuidString) }
            + groupIds.map { ForwardTargetParam(kind: "group", id: $0.uuidString) }
        guard !targets.isEmpty else { return }
        // One edge-function call per source message (multi-select forwards several).
        for messageId in source.messageIds {
            let request = ForwardRequest(
                source: ForwardSourceParam(kind: source.kind.rawValue, messageId: messageId.uuidString),
                targets: targets
            )
            let response: ForwardResponse = try await supabase.functions.invoke(
                "forward-message",
                options: .init(body: request)
            )
            guard response.ok else {
                throw DataError(message: "Forward failed")
            }
        }
        await loadConversations()
    }

    // MARK: - Discover

    @MainActor
    func loadDiscover() async {
        // Discover shows ONLY real DB rows now (no SampleData fallback). Brands and
        // campaigns load independently via their dedicated RPCs so a failure in one
        // never clobbers the other; an error leaves the prior list untouched and the
        // view shows its empty state when there's genuinely nothing.
        do {
            let bRows: [BrandRow] = try await supabase
                .rpc("list_discover_brands")
                .execute()
                .value
            brands = bRows.map { row in
                Brand(
                    id: row.id, name: row.name, category: row.category ?? "",
                    tagline: row.tagline ?? "", symbol: row.symbol ?? "sparkles",
                    colors: parseColors(row.colors), activeCampaigns: row.activeCampaigns ?? 0,
                    featuredRank: row.featuredRank, iconUrl: row.iconUrl,
                    applicationCount: row.applicationCount ?? 0
                )
            }
        } catch {
            print("⚠️ Brands load failed: \(error)")
        }

        do {
            let cRows: [CampaignRow] = try await supabase
                .rpc("list_discover_campaigns")
                .execute()
                .value
            campaigns = cRows.map { row in
                Campaign(
                    id: row.id, title: row.title, brand: row.brand, brandId: row.brandId,
                    budget: row.budget ?? "", tags: row.tags ?? [], deadline: row.deadline ?? "",
                    symbol: row.symbol ?? "sparkles", colors: parseColors(row.colors),
                    spotsLeft: row.spotsLeft ?? 0, description: row.description ?? "",
                    iconUrl: row.iconUrl, applicationCount: row.applicationCount ?? 0,
                    applied: row.applied ?? false
                )
            }
        } catch {
            print("⚠️ Campaigns load failed: \(error)")
        }
    }

    /// Applies the current user to a campaign (idempotent server-side; decrements
    /// spots_left once). Callers refresh Discover after to reflect server truth.
    @MainActor
    func applyToCampaign(_ id: UUID) async throws {
        try await supabase
            .rpc("apply_to_campaign", params: CampaignApplyParams(p_campaign: id.uuidString))
            .execute()
    }

    /// Withdraws the current user's application from a campaign (gives the spot back).
    @MainActor
    func withdrawFromCampaign(_ id: UUID) async throws {
        try await supabase
            .rpc("withdraw_from_campaign", params: CampaignApplyParams(p_campaign: id.uuidString))
            .execute()
    }

    /// The caller's applied campaign ids (server is the source of truth). Used to
    /// seed/replace the on-device applied list.
    @MainActor
    func loadMyApplications() async throws -> [UUID] {
        try await supabase
            .rpc("list_my_applications")
            .execute()
            .value
    }

    /// Uploads a compressed icon to the public `discover` bucket and returns its
    /// public URL. Mirrors `uploadAvatar`. `kind` is "brand" or "campaign"; the path
    /// is `{kind}/{id}-{uuid}.jpg` (lowercased to satisfy Storage policies).
    @MainActor
    func uploadDiscoverIcon(kind: String, id: UUID, imageData: Data) async throws -> String {
        let compressed = Self.compressedJPEG(imageData, maxDimension: 512, quality: 0.82) ?? imageData
        let filePath = "\(kind.lowercased())/\(id.uuidString.lowercased())-\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage
            .from("discover")
            .upload(filePath, data: compressed, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try supabase.storage
            .from("discover")
            .getPublicURL(path: filePath)
        return publicURL.absoluteString
    }
}

// MARK: - Helpers

/// Parses a JSON array string like "[10128661,16726362]" into [UInt].
private func parseColors(_ raw: String?) -> [UInt] {
    guard let raw,
          let data = raw.data(using: .utf8),
          let arr = try? JSONDecoder().decode([UInt].self, from: data)
    else { return [0xFF4D6D, 0xFF9A5A] }
    return arr
}
