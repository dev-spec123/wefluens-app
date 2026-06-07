//
//  AppDataService.swift
//  Wefluens
//
//  Central data service that bridges Supabase rows ↔ domain models.
//  Falls back to SampleData when the user is not authenticated.
//

import Foundation
import Supabase

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

    var isLoadingConversations = false
    var isLoadingContacts = false
    var isLoadingProfile = false

    let userId: UUID?

    init(userId: UUID?) {
        self.userId = userId
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
                    avatarUrl: row.avatarUrl
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
                    avatarUrl: row.avatarUrl
                )
            }
        } catch {
            print("⚠️ Profile refresh failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Avatar

    @MainActor
    func uploadAvatar(userId: UUID, imageData: Data) async -> String? {
        let filePath = "\(userId.uuidString)/avatar-\(UUID().uuidString).jpg"
        do {
            let file = File(name: filePath, data: imageData, fileName: "avatar.jpg", contentType: "image/jpeg")
            try await supabase.storage
                .from("avatars")
                .upload(filePath, data: imageData)
            let publicURL = try supabase.storage
                .from("avatars")
                .getPublicURL(path: filePath)
            return publicURL.absoluteString
        } catch {
            print("⚠️ Avatar upload failed: \(error)")
            return nil
        }
    }

    /// Persist profile fields to Supabase via upsert — works even if the row
    /// was never created by syncProfile. Throws on failure so the caller can show an error.
    @MainActor
    func updateProfile(name: String, bio: String, location: String, avatarUrl: String? = nil) async throws {
        guard let uid = userId else {
            throw DataError(message: "Not signed in")
        }

        // Upsert guarantees the row exists — safe even when syncProfile failed silently.
        let upsert = ProfileUpsert(
            id: uid,
            email: nil,
            name: name,
            avatarUrl: avatarUrl,
            handle: nil,
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
            if let url = avatarUrl {
                profile?.avatarUrl = url
            }
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

    /// Loads the real 1:1 DM threads via the `list_dm_threads` RPC (other person's
    /// profile + last-message preview + my unread count, one round trip). The old
    /// per-user `conversations`/`messages` tables are no longer used here.
    @MainActor
    func loadConversations() async {
        guard let uid = userId else {
            conversations = SampleData.conversations
            return
        }
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        do {
            let rows: [DMThreadListRow] = try await supabase
                .rpc("list_dm_threads")
                .execute()
                .value

            conversations = rows.map { row in
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
                    lastFromMe: row.lastSenderId == uid
                )
            }
        } catch {
            print("⚠️ DM threads load failed: \(error)")
            conversations = []
        }
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
        return results
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
            isOnline: false
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

    /// Short clock time (locale-aware, e.g. "9:05 AM" or "21:05") for a message.
    nonisolated static func clockTime(from date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
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
            let rf = RelativeDateTimeFormatter()
            rf.dateTimeStyle = .named
            return rf.localizedString(for: cal.startOfDay(for: date), relativeTo: cal.startOfDay(for: Date()))
        }
        let f = DateFormatter()
        let sameYear = cal.isDate(date, equalTo: Date(), toGranularity: .year)
        f.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd" : "yMMMd")
        return f.string(from: date)
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

    // MARK: - Direct Messages (1:1 chat)

    /// Total unread across all DM threads — drives the Chats tab badge.
    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unread }
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
    func sendMessage(to otherId: UUID, body: String) async throws -> UUID {
        let raw: String = try await supabase
            .rpc("send_dm", params: SendDMParams(p_other: otherId.uuidString, p_body: body))
            .execute()
            .value
        await loadConversations()
        guard let threadId = UUID(uuidString: raw) else {
            throw DataError(message: "Invalid thread id")
        }
        return threadId
    }

    /// Loads all messages in a thread (RLS limits this to the two participants),
    /// mapped to the UI `ChatMessage` model.
    @MainActor
    func loadThreadMessages(threadId: UUID) async -> [ChatMessage] {
        guard let uid = userId else { return [] }
        do {
            let rows: [DMMessageRow] = try await supabase
                .from("dm_messages")
                .select()
                .eq("thread_id", value: threadId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            return rows.map { row in
                ChatMessage(
                    id: row.id,
                    text: row.body,
                    sender: row.senderId == uid ? .me : .them,
                    time: Self.clockTime(from: row.createdAt)
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
    /// scopes delivered inserts to threads I'm part of, so any new DM (incoming or
    /// my own) refreshes the inbox.
    @MainActor
    func observeInbox() async {
        guard let uid = userId else { return }
        let channel = supabase.channel("dm-inbox-\(uid.uuidString)")
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "dm_messages")
        await channel.subscribe()
        defer {
            let ch = channel
            Task { await ch.unsubscribe(); await supabase.removeChannel(ch) }
        }
        for await _ in inserts {
            await loadConversations()
        }
    }

    // MARK: - Discover

    @MainActor
    func loadDiscover() async {
        do {
            let bRows: [BrandRow] = try await supabase
                .from("brands")
                .select()
                .execute()
                .value

            brands = bRows.map { row in
                Brand(
                    id: row.id,
                    name: row.name,
                    category: row.category ?? "",
                    tagline: row.tagline ?? "",
                    symbol: row.symbol ?? "sparkles",
                    colors: parseColors(row.colors),
                    activeCampaigns: row.activeCampaigns ?? 0
                )
            }

            let cRows: [CampaignRow] = try await supabase
                .from("campaigns")
                .select()
                .execute()
                .value

            campaigns = cRows.map { row in
                Campaign(
                    id: row.id,
                    title: row.title,
                    brand: row.brand,
                    budget: row.budget ?? "",
                    tags: row.tags ?? [],
                    deadline: row.deadline ?? "",
                    symbol: row.symbol ?? "sparkles",
                    colors: parseColors(row.colors),
                    spotsLeft: row.spotsLeft ?? 0
                )
            }

            if brands.isEmpty { brands = SampleData.brands }
            if campaigns.isEmpty { campaigns = SampleData.campaigns }
        } catch {
            print("⚠️ Discover load failed: \(error)")
            brands = SampleData.brands
            campaigns = SampleData.campaigns
        }
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
