//
//  Models.swift
//  Wefluens
//
//  Domain models for chats, contacts, discover content and the user.
//

import SwiftUI

// MARK: - Chat

enum MessageSender: Equatable {
    case me
    case them
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let sender: MessageSender
    let time: String

    init(id: UUID = UUID(), text: String, sender: MessageSender, time: String) {
        self.id = id
        self.text = text
        self.sender = sender
        self.time = time
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

    init(id: UUID = UUID(), name: String, avatar: String, avatarColors: [UInt], lastMessage: String, time: String, unread: Int, isPinned: Bool, isOfficial: Bool, isOnline: Bool, isGroup: Bool, participantCount: Int, messages: [ChatMessage], otherUserId: UUID? = nil, avatarInitials: String? = nil, lastMessageAt: Date? = nil, lastFromMe: Bool = false) {
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

    var id: UUID { threadId }
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

    init(id: UUID = UUID(), name: String, handle: String, role: String, platform: String, followers: String, avatarColors: [UInt], isOnline: Bool) {
        self.id = id
        self.name = name
        self.handle = handle
        self.role = role
        self.platform = platform
        self.followers = followers
        self.avatarColors = avatarColors
        self.isOnline = isOnline
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
