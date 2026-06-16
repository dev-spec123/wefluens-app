//
//  DatabaseModels.swift
//  WeConnect
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
    /// Server-controlled access flag — true unlocks all features beyond the free
    /// 1:1 chat + add-friends tier. The client only ever READS this.
    let isFullAccess: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, name, handle, role, bio, location, followers, engagement, deals
        case avatarUrl = "avatar_url"
        case isAdmin = "is_admin"
        case isFullAccess = "is_full_access"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Blocks & Reports

/// One row from `blocks` — a user I've blocked.
nonisolated struct BlockRow: Codable, Sendable {
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
    }
}

nonisolated struct BlockInsert: Encodable, Sendable {
    let blockerId: UUID
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

/// Insert payload for a content/user report.
nonisolated struct ReportInsert: Encodable, Sendable {
    let reporterId: UUID
    let reportedUserId: UUID?
    let messageId: UUID?
    let messageKind: String?
    let contentExcerpt: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case messageId = "message_id"
        case messageKind = "message_kind"
        case contentExcerpt = "content_excerpt"
        case reason
    }
}

/// Update payload to stamp terms acceptance on the caller's profile.
nonisolated struct TermsAcceptedUpdate: Encodable, Sendable {
    let terms_accepted_at: String
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
    let lastMessageType: String?
    let lastMessageRecalled: Bool?
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
        case lastMessageType = "last_message_type"
        case lastMessageRecalled = "last_message_recalled"
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
    let messageType: String?
    let imageUrl: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let fileName: String?
    let fileSize: Int?
    let fileMime: String?
    let readAt: Date?
    let createdAt: Date?
    let replyToMessageId: UUID?
    let recalledAt: Date?
    let recalledBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id, body
        case threadId = "thread_id"
        case senderId = "sender_id"
        case recipientId = "recipient_id"
        case messageType = "message_type"
        case imageUrl = "image_url"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case fileName = "file_name"
        case fileSize = "file_size"
        case fileMime = "file_mime"
        case readAt = "read_at"
        case createdAt = "created_at"
        case replyToMessageId = "reply_to_message_id"
        case recalledAt = "recalled_at"
        case recalledBy = "recalled_by"
    }
}

nonisolated struct GetOrCreateThreadParams: Encodable, Sendable {
    let p_other: String
}

nonisolated struct SendDMParams: Encodable, Sendable {
    let p_other: String
    let p_body: String
    /// Optional id of the quoted message. Omitted (nil) → server default NULL → unchanged behavior.
    let p_reply_to: String?
}

nonisolated struct SendDMMediaParams: Encodable, Sendable {
    let p_other: String
    let p_image_url: String
    let p_caption: String
    let p_width: Int
    let p_height: Int
    /// Optional id of the quoted message. Omitted (nil) → server default NULL → unchanged behavior.
    let p_reply_to: String?
}

/// Params for the generic `send_dm_attachment` RPC (file / video). Optional
/// metadata is omitted when nil so the server defaults apply.
nonisolated struct SendDMAttachmentParams: Encodable, Sendable {
    let p_other: String
    let p_type: String
    let p_path: String
    let p_caption: String
    let p_file_name: String?
    let p_file_size: Int?
    let p_file_mime: String?
    /// Optional id of the quoted message. Omitted (nil) → server default NULL → unchanged behavior.
    let p_reply_to: String?
}

nonisolated struct MarkThreadReadParams: Encodable, Sendable {
    let p_thread: String
}

// MARK: - Group Chat

/// One row from the `list_group_threads` RPC — a group plus its member count,
/// last-message preview, and my unread count.
nonisolated struct GroupThreadListRow: Codable, Identifiable, Sendable {
    let groupId: UUID
    let name: String?
    let avatarUrl: String?
    let createdBy: UUID?
    let lastMessage: String?
    let lastMessageAt: Date?
    let lastSenderId: UUID?
    let lastMessageType: String?
    let lastMessageRecalled: Bool?
    let memberCount: Int
    let unreadCount: Int

    var id: UUID { groupId }

    enum CodingKeys: String, CodingKey {
        case name
        case groupId = "group_id"
        case avatarUrl = "avatar_url"
        case createdBy = "created_by"
        case lastMessage = "last_message"
        case lastMessageAt = "last_message_at"
        case lastSenderId = "last_sender_id"
        case lastMessageType = "last_message_type"
        case lastMessageRecalled = "last_message_recalled"
        case memberCount = "member_count"
        case unreadCount = "unread_count"
    }
}

/// The sender profile embedded in a group message read (`profiles` is world-readable,
/// so this resolves even for co-members who aren't my friends).
nonisolated struct GroupMessageSender: Codable, Sendable {
    let id: UUID
    let name: String?
    let handle: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, handle
        case avatarUrl = "avatar_url"
    }
}

/// A single group message row from `group_messages`, with its sender's profile
/// embedded via the `group_messages_sender_id_fkey` foreign key. Carries the same
/// media columns as `dm_messages` (image / file) so group bubbles reuse the 1:1 ones.
nonisolated struct GroupMessageRow: Codable, Identifiable, Sendable {
    let id: UUID
    let groupId: UUID
    let senderId: UUID
    let body: String
    let messageType: String?
    let imageUrl: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let fileName: String?
    let fileSize: Int?
    let fileMime: String?
    let createdAt: Date?
    let replyToMessageId: UUID?
    let recalledAt: Date?
    let recalledBy: UUID?
    let sender: GroupMessageSender?

    enum CodingKeys: String, CodingKey {
        case id, body, sender
        case groupId = "group_id"
        case senderId = "sender_id"
        case messageType = "message_type"
        case imageUrl = "image_url"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
        case fileName = "file_name"
        case fileSize = "file_size"
        case fileMime = "file_mime"
        case createdAt = "created_at"
        case replyToMessageId = "reply_to_message_id"
        case recalledAt = "recalled_at"
        case recalledBy = "recalled_by"
    }
}

/// Params for the `create_group` RPC. Member ids are the selected friends'
/// profile ids (the server adds me as admin and validates each via `are_friends`).
nonisolated struct CreateGroupParams: Encodable, Sendable {
    let p_name: String
    let p_member_ids: [String]
}

nonisolated struct SendGroupMessageParams: Encodable, Sendable {
    let p_group: String
    let p_body: String
    /// Optional id of the quoted message. Omitted (nil) → server default NULL → unchanged behavior.
    let p_reply_to: String?
}

/// Params for the generic `send_group_attachment` RPC (image / video / file),
/// mirroring `send_dm_attachment` but member-validated. Optional metadata encodes
/// as JSON null when nil, which equals the server-side NULL defaults.
nonisolated struct SendGroupAttachmentParams: Encodable, Sendable {
    let p_group: String
    let p_type: String
    let p_path: String
    let p_caption: String
    let p_file_name: String?
    let p_file_size: Int?
    let p_file_mime: String?
    let p_width: Int?
    let p_height: Int?
    /// Optional id of the quoted message. Omitted (nil) → server default NULL → unchanged behavior.
    let p_reply_to: String?
}

nonisolated struct MarkGroupReadParams: Encodable, Sendable {
    let p_group: String
}

// MARK: - Group Settings

/// One member returned by `list_group_members` — profile fields + role + owner flag.
nonisolated struct GroupMemberRow: Codable, Identifiable, Sendable {
    let userId: UUID
    let name: String?
    let handle: String?
    let avatarUrl: String?
    let role: String
    let isOwner: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case name, handle, role
        case userId = "user_id"
        case avatarUrl = "avatar_url"
        case isOwner = "is_owner"
    }
}

nonisolated struct GroupIdParam: Encodable, Sendable {
    let p_group: String
}

nonisolated struct GroupRenameParams: Encodable, Sendable {
    let p_group: String
    let p_name: String
}

nonisolated struct GroupMemberParams: Encodable, Sendable {
    let p_group: String
    let p_user: String
}

// MARK: - Delete / Recall / Clear (RPC params + data rows)

/// A row from `message_deletions` — messages the current user has soft-deleted.
nonisolated struct MessageDeletionRow: Codable, Sendable {
    let messageId: UUID
    let kind: String

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case kind
    }
}

/// The caller's clear watermark for a DM thread.
nonisolated struct DMClearRow: Codable, Sendable {
    let threadId: UUID
    let clearedBefore: Date

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case clearedBefore = "cleared_before"
    }
}

/// The caller's clear watermark for a group thread.
nonisolated struct GroupClearRow: Codable, Sendable {
    let groupId: UUID
    let clearedBefore: Date

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case clearedBefore = "cleared_before"
    }
}

nonisolated struct DeleteMessageParams: Encodable, Sendable {
    let p_message_id: String
    let p_kind: String
}

nonisolated struct RecallMessageParams: Encodable, Sendable {
    let p_message_id: String
    let p_kind: String
}

nonisolated struct ClearDMHistoryParams: Encodable, Sendable {
    let p_thread_id: String
}

nonisolated struct HideConversationParams: Encodable, Sendable {
    let p_conversation_id: String
    let p_conversation_type: String
}

nonisolated struct ClearGroupHistoryParams: Encodable, Sendable {
    let p_group_id: String
}

// MARK: - Forward Message (edge function payload)

/// Identifies the message being forwarded (its kind + id) for the
/// `forward-message` edge function.
nonisolated struct ForwardSourceParam: Encodable, Sendable {
    let kind: String          // "dm" | "group"
    let messageId: String
}

/// One forward destination: a friend (1:1) or a group I'm a member of.
nonisolated struct ForwardTargetParam: Encodable, Sendable {
    let kind: String          // "friend" | "group"
    let id: String
}

nonisolated struct ForwardRequest: Encodable, Sendable {
    let source: ForwardSourceParam
    let targets: [ForwardTargetParam]
}

/// Result summary from `forward-message` (per-target detail is logged server-side).
nonisolated struct ForwardResponse: Codable, Sendable {
    let ok: Bool
    let forwarded: Int?
    let failed: Int?
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
