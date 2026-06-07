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
            let cRows: [ContactDBRow] = try await supabase
                .from("contacts")
                .select()
                .eq("user_id", value: uid.uuidString)
                .execute()
                .value

            contacts = cRows.map { row in
                Contact(
                    id: row.id,
                    name: row.name,
                    handle: row.handle ?? "",
                    role: row.role ?? "",
                    platform: row.platform ?? "",
                    followers: row.followers ?? "0",
                    avatarColors: parseColors(row.avatarColors),
                    isOnline: row.isOnline ?? false
                )
            }

            let fRows: [FriendRequestDBRow] = try await supabase
                .from("friend_requests")
                .select()
                .eq("to_user_id", value: uid.uuidString)
                .eq("status", value: "pending")
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
        } catch {
            print("⚠️ Contacts load failed: \(error)")
            contacts = SampleData.contacts
            friendRequests = SampleData.friendRequests
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
