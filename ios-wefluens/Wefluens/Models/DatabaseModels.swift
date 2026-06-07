//
//  DatabaseModels.swift
//  Wefluens
//
//  Supabase row structs — nonisolated + Sendable for SWIFT_DEFAULT_ACTOR_ISOLATION.
//  user_id columns are now UUID (native Supabase Auth).
//

import Foundation

// MARK: - Profile

nonisolated struct ProfileRow: Codable, Identifiable, Sendable {
    let id: UUID
    let email: String?
    let name: String?
    let avatarUrl: String?
    let handle: String?
    let role: String?
    let bio: String?
    let location: String?
    let followers: String?
    let engagement: String?
    let deals: String?
    let isAdmin: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name, handle, role, bio, location, followers, engagement, deals
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ProfileUpsert: Encodable, Sendable {
    let id: UUID
    let email: String?
    let name: String?
    let avatarUrl: String?
    let handle: String?
    let role: String?
    let bio: String?
    let location: String?
    let followers: String?
    let engagement: String?
    let deals: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, name, handle, role, bio, location, followers, engagement, deals
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
    }
}

// MARK: - Conversation

nonisolated struct ConversationDBRow: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let avatar: String?
    let avatarColors: String?
    let lastMessage: String?
    let time: String?
    let unread: Int?
    let isPinned: Bool?
    let isOfficial: Bool?
    let isOnline: Bool?
    let isGroup: Bool?
    let participantCount: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, avatar, time, unread
        case userId = "user_id"
        case avatarColors = "avatar_colors"
        case lastMessage = "last_message"
        case isPinned = "is_pinned"
        case isOfficial = "is_official"
        case isOnline = "is_online"
        case isGroup = "is_group"
        case participantCount = "participant_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ConversationInsert: Encodable, Sendable {
    let userId: UUID
    let name: String
    let avatar: String?
    let avatarColors: String?
    let lastMessage: String?
    let time: String?
    let unread: Int?
    let isPinned: Bool?
    let isOfficial: Bool?
    let isOnline: Bool?
    let isGroup: Bool?
    let participantCount: Int?

    enum CodingKeys: String, CodingKey {
        case name, avatar, time, unread
        case userId = "user_id"
        case avatarColors = "avatar_colors"
        case lastMessage = "last_message"
        case isPinned = "is_pinned"
        case isOfficial = "is_official"
        case isOnline = "is_online"
        case isGroup = "is_group"
        case participantCount = "participant_count"
    }
}

// MARK: - Message

nonisolated struct MessageRow: Codable, Identifiable, Sendable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let text: String
    let time: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, text, time
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
    }
}

nonisolated struct MessageInsert: Encodable, Sendable {
    let conversationId: UUID
    let senderId: UUID
    let text: String
    let time: String?

    enum CodingKeys: String, CodingKey {
        case text, time
        case conversationId = "conversation_id"
        case senderId = "sender_id"
    }
}

// MARK: - Contact

nonisolated struct ContactDBRow: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let handle: String?
    let role: String?
    let platform: String?
    let followers: String?
    let avatarColors: String?
    let isOnline: Bool?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, handle, role, platform, followers
        case userId = "user_id"
        case avatarColors = "avatar_colors"
        case isOnline = "is_online"
        case createdAt = "created_at"
    }
}

// MARK: - Friend Request

nonisolated struct FriendRequestDBRow: Codable, Identifiable, Sendable {
    let id: UUID
    let fromUserId: UUID
    let toUserId: UUID
    let name: String
    let handle: String?
    let role: String?
    let avatarColors: String?
    let requestMessage: String?
    let status: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, handle, role, status
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case avatarColors = "avatar_colors"
        case requestMessage = "request_message"
        case createdAt = "created_at"
    }
}

// MARK: - Brand

nonisolated struct BrandRow: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: String?
    let tagline: String?
    let symbol: String?
    let colors: String?
    let activeCampaigns: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, category, tagline, symbol, colors
        case activeCampaigns = "active_campaigns"
        case createdAt = "created_at"
    }
}

// MARK: - Friendships & Friend RPCs

/// Lightweight row for reading the friend graph (`select("friend_id")`).
nonisolated struct FriendshipFriendRow: Codable, Sendable {
    let friendId: UUID

    enum CodingKeys: String, CodingKey {
        case friendId = "friend_id"
    }
}

/// One result from the `search_users` RPC. Email is intentionally NOT included —
/// the server matches on it but never returns it.
nonisolated struct SearchUserResult: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let handle: String
    let role: String
    let avatarUrl: String?
    let followers: String
    /// One of: "none", "friends", "request_sent", "request_received".
    let relationship: String
    /// When relationship == "request_received", the id of that pending request
    /// so it can be accepted inline.
    let incomingRequestId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, handle, role, followers, relationship
        case avatarUrl = "avatar_url"
        case incomingRequestId = "incoming_request_id"
    }
}

nonisolated struct SearchUsersParams: Encodable, Sendable {
    let search_query: String
}

nonisolated struct SendFriendRequestParams: Encodable, Sendable {
    let target_id: String
    let message: String
}

nonisolated struct RespondFriendRequestParams: Encodable, Sendable {
    let request_id: String
    let accept: Bool
}

/// Removes a friend in both directions atomically (calls the `remove_friend`
/// SECURITY DEFINER function).
nonisolated struct RemoveFriendParams: Encodable, Sendable {
    let target_id: String
}

/// Marks a sender's accepted request as seen (clears the in-app prompt).
nonisolated struct SeenBySenderUpdate: Encodable, Sendable {
    let seen_by_sender: Bool
}

// MARK: - Direct Messages (1:1 chat)

/// One row from the `list_dm_threads` RPC — a thread plus the other participant's
/// profile, last-message preview, and my unread count.
nonisolated struct DMThreadListRow: Codable, Identifiable, Sendable {
    let threadId: UUID
    let otherId: UUID
    let otherName: String?
    let otherHandle: String?
    let otherRole: String?
    let otherAvatarUrl: String?
    let lastMessage: String?
    let lastMessageAt: Date?
    let lastSenderId: UUID?
    let unreadCount: Int

    var id: UUID { threadId }

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case otherId = "other_id"
        case otherName = "other_name"
        case otherHandle = "other_handle"
        case otherRole = "other_role"
        case otherAvatarUrl = "other_avatar_url"
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case lastSenderId = "last_sender_id"
        case unreadCount = "unread_count"
    }
}

/// A single direct message row from `dm_messages`.
nonisolated struct DMMessageRow: Codable, Identifiable, Sendable {
    let id: UUID
    let threadId: UUID
    let senderId: UUID
    let recipientId: UUID
    let body: String
    let readAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, body
        case threadId = "thread_id"
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

nonisolated struct GetOrCreateThreadParams: Encodable, Sendable {
    let p_other: String
}

nonisolated struct SendDMParams: Encodable, Sendable {
    let p_other: String
    let p_body: String
}

nonisolated struct MarkThreadReadParams: Encodable, Sendable {
    let p_thread: String
}

// MARK: - Campaign

nonisolated struct CampaignRow: Codable, Identifiable, Sendable {
    let id: UUID
    let brandId: UUID?
    let title: String
    let brand: String
    let budget: String?
    let tags: [String]?
    let deadline: String?
    let symbol: String?
    let colors: String?
    let spotsLeft: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, brand, budget, tags, deadline, symbol, colors
        case brandId = "brand_id"
        case spotsLeft = "spots_left"
        case createdAt = "created_at"
    }
}
