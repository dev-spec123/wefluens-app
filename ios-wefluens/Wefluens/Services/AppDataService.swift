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

    @MainActor
    func loadConversations() async {
        guard let uid = userId else {
            conversations = SampleData.conversations
            return
        }
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        do {
            let rows: [ConversationDBRow] = try await supabase
                .from("conversations")
                .select()
                .eq("user_id", value: uid.uuidString)
                .order("updated_at", ascending: false)
                .execute()
                .value

            var convos: [Conversation] = []
            for row in rows {
                let msgRows: [MessageRow] = (try? await supabase
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: row.id.uuidString)
                    .order("created_at", ascending: true)
                    .execute()
                    .value) ?? []

                let messages = msgRows.map { msg in
                    ChatMessage(
                        id: msg.id,
                        text: msg.text,
                        sender: msg.senderId == uid ? .me : .them,
                        time: msg.time ?? ""
                    )
                }

                convos.append(Conversation(
                    id: row.id,
                    name: row.name,
                    avatar: row.avatar ?? "person.fill",
                    avatarColors: parseColors(row.avatarColors),
                    lastMessage: row.lastMessage ?? "",
                    time: row.time ?? "",
                    unread: row.unread ?? 0,
                    isPinned: row.isPinned ?? false,
                    isOfficial: row.isOfficial ?? false,
                    isOnline: row.isOnline ?? false,
                    isGroup: row.isGroup ?? false,
                    participantCount: row.participantCount ?? 0,
                    messages: messages
                ))
            }
            conversations = convos
        } catch {
            print("⚠️ Conversations load failed: \(error)")
            conversations = SampleData.conversations
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
