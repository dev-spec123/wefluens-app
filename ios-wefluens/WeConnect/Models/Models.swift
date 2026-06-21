//
//  Models.swift
//  WeConnect
//
//  Domain models for chats, contacts, discover content and the user.
//

import SwiftUI

// MARK: - Chat

enum MessageSender: String, Codable, Equatable {
    case me
    case them
}

/// A direct message is plain text, an image, a video, a file attachment, or a
/// voice/audio recording (media kinds may carry an optional caption).
enum ChatMessageKind: String, Codable, Equatable {
    case text
    case image
    case video
    case file
    case audio
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let sender: MessageSender
    let time: String
    let kind: ChatMessageKind
    /// Storage path in the private `chat-media` bucket (any media message).
    let imagePath: String?
    let imageWidth: Int?
    let imageHeight: Int?
    /// File-attachment metadata (file messages only).
    let fileName: String?
    let fileSize: Int?
    let fileMime: String?
    /// When the recipient read this message. Only meaningful for messages I sent:
    /// `nil` = delivered but unread, non-nil = read. Drives the read receipt.
    let readAt: Date?
    /// Id of the message this one quotes (nil for a normal message). Resolved
    /// against the loaded thread to render the quoted preview above the bubble.
    let replyTo: UUID?
    /// True when the sender recalled this message (shows "Message recalled" placeholder).
    let isRecalled: Bool
    /// The sender's user id (used to gate recall: only the sender can recall).
    let senderId: UUID?
    /// When this message was created (server timestamptz). Used by the client-side
    /// 2-minute recall window gate so the button isn't shown for expired messages.
    let createdAt: Date?

    init(id: UUID = UUID(), text: String, sender: MessageSender, time: String,
         kind: ChatMessageKind = .text, imagePath: String? = nil,
         imageWidth: Int? = nil, imageHeight: Int? = nil,
         fileName: String? = nil, fileSize: Int? = nil, fileMime: String? = nil,
         readAt: Date? = nil, replyTo: UUID? = nil,
         isRecalled: Bool = false, senderId: UUID? = nil,
         createdAt: Date? = nil) {
        self.id = id
        self.text = text
        self.sender = sender
        self.time = time
        self.kind = kind
        self.imagePath = imagePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileMime = fileMime
        self.readAt = readAt
        self.replyTo = replyTo
        self.isRecalled = isRecalled
        self.senderId = senderId
        self.createdAt = createdAt
    }
}

struct Conversation: Identifiable {
    let id: UUID
    let name: String
    let avatar: String
    let avatarColors: [UInt]
    let lastMessage: String
    let time: String
    let unread: Int
    let isPinned: Bool
    let isOfficial: Bool
    let isOnline: Bool
    let isGroup: Bool
    let participantCount: Int
    let messages: [ChatMessage]
    /// For real 1:1 DM threads: the other participant's user id (nil for sample data).
    let otherUserId: UUID?
    /// Initials to render in the avatar for DM threads (profiles have no SF symbol).
    let avatarInitials: String?
    /// Raw timestamp of the last message, used for sorting.
    let lastMessageAt: Date?
    /// True when the last message was sent by me (drives the "You: " preview prefix).
    let lastFromMe: Bool
    /// True when the last message is an image — shows a localized "[Photo]" preview when there's no caption.
    let lastMessageIsImage: Bool
    /// Kind of the last message ("text"/"image"/"video"/"file") — drives the localized media preview.
    let lastMessageType: String
    /// True when the last visible message was recalled by its sender → shows placeholder in preview.
    let lastMessageRecalled: Bool
    /// The other participant's profile photo URL (nil for sample data / groups).
    let avatarUrl: String?

    init(id: UUID = UUID(), name: String, avatar: String, avatarColors: [UInt], lastMessage: String, time: String, unread: Int, isPinned: Bool, isOfficial: Bool, isOnline: Bool, isGroup: Bool, participantCount: Int, messages: [ChatMessage], otherUserId: UUID? = nil, avatarInitials: String? = nil, lastMessageAt: Date? = nil, lastFromMe: Bool = false, lastMessageIsImage: Bool = false, lastMessageType: String = "text", lastMessageRecalled: Bool = false, avatarUrl: String? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.avatarColors = avatarColors
        self.lastMessage = lastMessage
        self.time = time
        self.unread = unread
        self.isPinned = isPinned
        self.isOfficial = isOfficial
        self.isOnline = isOnline
        self.isGroup = isGroup
        self.participantCount = participantCount
        self.messages = messages
        self.otherUserId = otherUserId
        self.avatarInitials = avatarInitials
        self.lastMessageAt = lastMessageAt
        self.lastFromMe = lastFromMe
        self.lastMessageIsImage = lastMessageIsImage
        self.lastMessageType = lastMessageType
        self.lastMessageRecalled = lastMessageRecalled
        self.avatarUrl = avatarUrl
    }
}

/// Lightweight, Hashable navigation route to open a 1:1 chat from anywhere
/// (the chat list or a contact's detail screen).
struct DMChatRoute: Hashable, Identifiable {
    let threadId: UUID
    let otherUserId: UUID
    let title: String
    let avatarColors: [UInt]
    let initials: String
    let isOnline: Bool
    /// The other participant's profile photo URL (nil when unknown).
    let avatarURL: String?

    var id: UUID { threadId }
}

/// Hashable navigation route to open a group chat (the chat list or right after
/// creating a new group).
struct GroupChatRoute: Hashable, Identifiable {
    let groupId: UUID
    let title: String
    let avatarColors: [UInt]
    let memberCount: Int
    /// The group's avatar photo URL (nil — groups use a symbol avatar for now).
    let avatarURL: String?

    var id: UUID { groupId }
}

/// One message in a group thread. Unlike a 1:1 `ChatMessage`, every message
/// carries its sender's identity so incoming bubbles can show who sent it
/// (avatar + name). Supports text, image, and file kinds (mirrors `ChatMessage`).
struct GroupChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let sender: MessageSender
    /// The sender's profile id (used to group consecutive messages from one person).
    let senderId: UUID
    /// Display name shown above incoming bubbles.
    let senderName: String
    /// Deterministic gradient for the sender's avatar fallback.
    let senderColors: [UInt]
    /// The sender's profile photo URL (nil → gradient + initials).
    let senderAvatarUrl: String?
    let time: String
    /// Message kind — text / image / file (video falls back to its caption for now).
    let kind: ChatMessageKind
    /// Storage path in the private `chat-media` bucket (any media message).
    let imagePath: String?
    let imageWidth: Int?
    let imageHeight: Int?
    /// File-attachment metadata (file messages only).
    let fileName: String?
    let fileSize: Int?
    let fileMime: String?
    /// True when the sender recalled this message (shows "Message recalled" placeholder).
    let isRecalled: Bool
    /// When this message was created (server timestamptz). Used by the client-side
    /// 2-minute recall window gate so the button isn't shown for expired messages.
    let createdAt: Date?

    init(id: UUID, text: String, sender: MessageSender, senderId: UUID,
         senderName: String, senderColors: [UInt], senderAvatarUrl: String?,
         time: String, kind: ChatMessageKind = .text, imagePath: String? = nil,
         imageWidth: Int? = nil, imageHeight: Int? = nil,
         fileName: String? = nil, fileSize: Int? = nil, fileMime: String? = nil,
         isRecalled: Bool = false,
         createdAt: Date? = nil) {
        self.id = id
        self.text = text
        self.sender = sender
        self.senderId = senderId
        self.senderName = senderName
        self.senderColors = senderColors
        self.senderAvatarUrl = senderAvatarUrl
        self.time = time
        self.kind = kind
        self.imagePath = imagePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileMime = fileMime
        self.isRecalled = isRecalled
        self.createdAt = createdAt
    }
}

/// What is being forwarded: identifies the source message + which store it lives
/// in. Used by the long-press → Forward flow to drive the target picker sheet.
enum ForwardKind: String, Sendable {
    case dm
    case group
}

struct ForwardSource: Identifiable, Equatable {
    let kind: ForwardKind
    let messageId: UUID
    var id: UUID { messageId }
}

/// A group member shown in the group settings roster (profile + role + owner flag).
struct GroupMember: Identifiable, Equatable {
    /// The member's profile / user id.
    let id: UUID
    let name: String
    let handle: String
    let avatarUrl: String?
    let role: String
    let isOwner: Bool

    var avatarColors: [UInt] { AppDataService.avatarPalette(for: id) }
    var initials: String { AppDataService.initials(from: name) }
}

// MARK: - Contacts

struct Contact: Identifiable {
    let id: UUID
    let name: String
    let handle: String
    let role: String
    let platform: String
    let followers: String
    let avatarColors: [UInt]
    let isOnline: Bool
    /// The friend's profile photo URL (nil when they have no avatar).
    let avatarUrl: String?

    init(id: UUID = UUID(), name: String, handle: String, role: String, platform: String, followers: String, avatarColors: [UInt], isOnline: Bool, avatarUrl: String? = nil) {
        self.id = id
        self.name = name
        self.handle = handle
        self.role = role
        self.platform = platform
        self.followers = followers
        self.avatarColors = avatarColors
        self.isOnline = isOnline
        self.avatarUrl = avatarUrl
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        return (first + last).uppercased()
    }
}

// MARK: - Friend Requests

struct FriendRequest: Identifiable {
    let id: UUID
    let name: String
    let handle: String
    let role: String
    let avatarColors: [UInt]
    let requestMessage: String

    init(id: UUID = UUID(), name: String, handle: String, role: String, avatarColors: [UInt], requestMessage: String) {
        self.id = id
        self.name = name
        self.handle = handle
        self.role = role
        self.avatarColors = avatarColors
        self.requestMessage = requestMessage
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        return (first + last).uppercased()
    }
}

// MARK: - Discover

struct Brand: Identifiable {
    let id: UUID
    let name: String
    let category: String
    let tagline: String
    let symbol: String
    let colors: [UInt]
    let activeCampaigns: Int

    init(id: UUID = UUID(), name: String, category: String, tagline: String, symbol: String, colors: [UInt], activeCampaigns: Int) {
        self.id = id
        self.name = name
        self.category = category
        self.tagline = tagline
        self.symbol = symbol
        self.colors = colors
        self.activeCampaigns = activeCampaigns
    }
}

struct Campaign: Identifiable {
    let id: UUID
    let title: String
    let brand: String
    let budget: String
    let tags: [String]
    let deadline: String
    let symbol: String
    let colors: [UInt]
    let spotsLeft: Int

    init(id: UUID = UUID(), title: String, brand: String, budget: String, tags: [String], deadline: String, symbol: String, colors: [UInt], spotsLeft: Int) {
        self.id = id
        self.title = title
        self.brand = brand
        self.budget = budget
        self.tags = tags
        self.deadline = deadline
        self.symbol = symbol
        self.colors = colors
        self.spotsLeft = spotsLeft
    }
}

// MARK: - User

struct UserProfile {
    var name: String
    var handle: String
    var role: String
    var bio: String
    var location: String
    var followers: String
    var engagement: String
    var deals: String
    var isAdmin: Bool
    var avatarUrl: String?
}
