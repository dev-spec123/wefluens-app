//
//  SampleData.swift
//  WeConnect
//
//  Static demo content powering the prototype.
//

import Foundation

enum SampleData {
    static let user = UserProfile(
        name: "Jordan Pierce",
        handle: "@jordanp",
        role: "Talent Manager · WeConnect",
        bio: "Connecting standout creators with brands that matter. LA based, globally minded.",
        location: "Los Angeles, CA",
        followers: "48.2K",
        engagement: "6.4%",
        deals: "127",
        isAdmin: false,
        avatarUrl: nil
    )

    static let conversations: [Conversation] = [
        Conversation(
            name: "WeConnect",
            avatar: "sparkles",
            avatarColors: [0xFF4D6D, 0xFF9A5A],
            lastMessage: "New brief from Glossier just dropped — take a look 🔥",
            time: "now",
            unread: 3,
            isPinned: true,
            isOfficial: true,
            isOnline: true,
            isGroup: false,
            participantCount: 0,
            messages: [
                ChatMessage(text: "Morning team! Hope everyone's caffeinated ☕️", sender: .them, time: "9:02 AM"),
                ChatMessage(text: "We just landed the Glossier summer campaign 🎉", sender: .them, time: "9:03 AM"),
                ChatMessage(text: "Amazing news! What's the scope?", sender: .me, time: "9:05 AM"),
                ChatMessage(text: "3 creators, reels + stories. Budget is solid.", sender: .them, time: "9:06 AM"),
                ChatMessage(text: "New brief from Glossier just dropped — take a look 🔥", sender: .them, time: "9:07 AM")
            ]
        ),
        Conversation(
            name: "Maya Rivera",
            avatar: "person.fill",
            avatarColors: [0x7B2FF7, 0xF107A3],
            lastMessage: "Sounds perfect, sending the deck over tonight!",
            time: "11:24 AM",
            unread: 2,
            isPinned: true,
            isOfficial: false,
            isOnline: true,
            isGroup: false,
            participantCount: 0,
            messages: [
                ChatMessage(text: "Hey! Are you free to chat about the Nike deal?", sender: .me, time: "10:40 AM"),
                ChatMessage(text: "Yes! I love the direction you pitched.", sender: .them, time: "10:55 AM"),
                ChatMessage(text: "Let's lock rates this week then.", sender: .me, time: "11:10 AM"),
                ChatMessage(text: "Sounds perfect, sending the deck over tonight!", sender: .them, time: "11:24 AM")
            ]
        ),
        Conversation(
            name: "Glossier Brand Team",
            avatar: "bag.fill",
            avatarColors: [0xFF8FB1, 0xFF5C8A],
            lastMessage: "Can the creators ship content by Friday?",
            time: "10:02 AM",
            unread: 0,
            isPinned: false,
            isOfficial: false,
            isOnline: false,
            isGroup: false,
            participantCount: 0,
            messages: [
                ChatMessage(text: "Thanks for the intro to your roster!", sender: .them, time: "9:30 AM"),
                ChatMessage(text: "Of course — they're a great fit.", sender: .me, time: "9:45 AM"),
                ChatMessage(text: "Can the creators ship content by Friday?", sender: .them, time: "10:02 AM")
            ]
        ),
        Conversation(
            name: "Theo Banks",
            avatar: "person.fill",
            avatarColors: [0x2AF598, 0x009EFD],
            lastMessage: "Just hit 1M on the last reel 🚀",
            time: "Yesterday",
            unread: 0,
            isPinned: false,
            isOfficial: false,
            isOnline: true,
            isGroup: false,
            participantCount: 0,
            messages: [
                ChatMessage(text: "Just hit 1M on the last reel 🚀", sender: .them, time: "8:12 PM"),
                ChatMessage(text: "Incredible! The brand will be thrilled.", sender: .me, time: "8:20 PM")
            ]
        ),
        Conversation(
            name: "Aria Chen",
            avatar: "person.fill",
            avatarColors: [0xFFB75E, 0xED8F03],
            lastMessage: "Can we move the call to 3pm?",
            time: "Yesterday",
            unread: 0,
            isPinned: false,
            isOfficial: false,
            isOnline: false,
            isGroup: false,
            participantCount: 0,
            messages: [
                ChatMessage(text: "Can we move the call to 3pm?", sender: .them, time: "4:50 PM"),
                ChatMessage(text: "Works for me 👍", sender: .me, time: "5:01 PM")
            ]
        ),
        Conversation(
            name: "Liam Foster",
            avatar: "person.fill",
            avatarColors: [0x654EA3, 0xEAAFC8],
            lastMessage: "Contract signed and returned ✅",
            time: "Mon",
            unread: 0,
            isPinned: false,
            isOfficial: false,
            isOnline: false,
            isGroup: false,
            participantCount: 0,
            messages: [
                ChatMessage(text: "Contract signed and returned ✅", sender: .them, time: "2:14 PM")
            ]
        ),
        // Group chat sample
        Conversation(
            name: "Nike Summer Campaign",
            avatar: "person.3.fill",
            avatarColors: [0xFF6B35, 0xF7C948],
            lastMessage: "Maya: I'll have the storyboards ready by tonight",
            time: "9:41 AM",
            unread: 5,
            isPinned: true,
            isOfficial: false,
            isOnline: true,
            isGroup: true,
            participantCount: 4,
            messages: [
                ChatMessage(text: "Welcome to the Nike Summer Campaign group!", sender: .them, time: "9:00 AM"),
                ChatMessage(text: "Hey everyone! Excited to work together 🎉", sender: .me, time: "9:02 AM"),
                ChatMessage(text: "Same here! Let's crush this one.", sender: .them, time: "9:05 AM"),
                ChatMessage(text: "I'll have the storyboards ready by tonight", sender: .them, time: "9:41 AM")
            ]
        )
    ]

    static let contacts: [Contact] = [
        Contact(name: "Maya Rivera", handle: "@mayalifestyle", role: "Lifestyle Creator", platform: "Instagram", followers: "820K", avatarColors: [0x7B2FF7, 0xF107A3], isOnline: true),
        Contact(name: "Theo Banks", handle: "@theobanks", role: "Fitness Creator", platform: "TikTok", followers: "1.2M", avatarColors: [0x2AF598, 0x009EFD], isOnline: true),
        Contact(name: "Aria Chen", handle: "@ariaeats", role: "Food Creator", platform: "YouTube", followers: "540K", avatarColors: [0xFFB75E, 0xED8F03], isOnline: false),
        Contact(name: "Liam Foster", handle: "@liamframes", role: "Photographer", platform: "Instagram", followers: "310K", avatarColors: [0x654EA3, 0xEAAFC8], isOnline: false),
        Contact(name: "Sofia Nadeem", handle: "@sofiastyle", role: "Fashion Creator", platform: "Instagram", followers: "960K", avatarColors: [0xFF5F6D, 0xFFC371], isOnline: true),
        Contact(name: "Glossier Brand Team", handle: "@glossier", role: "Brand Manager", platform: "Brand", followers: "Brand", avatarColors: [0xFF8FB1, 0xFF5C8A], isOnline: false),
        Contact(name: "Noah Kim", handle: "@noahtravels", role: "Travel Creator", platform: "YouTube", followers: "2.1M", avatarColors: [0x00C6FB, 0x005BEA], isOnline: false),
        Contact(name: "Bella Ortiz", handle: "@bellabeauty", role: "Beauty Creator", platform: "TikTok", followers: "1.5M", avatarColors: [0xF953C6, 0xB91D73], isOnline: true)
    ]

    static let friendRequests: [FriendRequest] = [
        FriendRequest(
            name: "Damon Liu",
            handle: "@damoncreates",
            role: "Visual Artist & Creator",
            avatarColors: [0x6C63FF, 0x3F3D9E],
            requestMessage: "Hi! I'm a visual artist — love the brands you work with. Let's connect!"
        )
    ]

    static let brands: [Brand] = [
        Brand(name: "Glossier", category: "Beauty", tagline: "Skin first. Makeup second.", symbol: "sparkles", colors: [0xFF8FB1, 0xFF5C8A], activeCampaigns: 3),
        Brand(name: "Aether", category: "Fashion", tagline: "Modern essentials, made to last.", symbol: "bag.fill", colors: [0x232526, 0x414345], activeCampaigns: 2),
        Brand(name: "Bloom", category: "Wellness", tagline: "Daily rituals for a calmer mind.", symbol: "leaf.fill", colors: [0x11998E, 0x38EF7D], activeCampaigns: 1),
        Brand(name: "Voltic", category: "Tech", tagline: "Power that keeps up with you.", symbol: "bolt.fill", colors: [0x396AFC, 0x2948FF], activeCampaigns: 4)
    ]

    static let campaigns: [Campaign] = [
        Campaign(title: "Summer Glow Launch", brand: "Glossier", budget: "$8K–12K", tags: ["Reels", "Beauty", "UGC"], deadline: "Jun 20", symbol: "sun.max.fill", colors: [0xFF6CAB, 0xFF5C8A], spotsLeft: 2),
        Campaign(title: "City Capsule Drop", brand: "Aether", budget: "$5K–9K", tags: ["Fashion", "Story"], deadline: "Jun 28", symbol: "tshirt.fill", colors: [0x434343, 0x000000], spotsLeft: 4),
        Campaign(title: "Morning Reset Ritual", brand: "Bloom", budget: "$3K–6K", tags: ["Wellness", "Reels"], deadline: "Jul 5", symbol: "leaf.fill", colors: [0x11998E, 0x38EF7D], spotsLeft: 6),
        Campaign(title: "Charge Anywhere", brand: "Voltic", budget: "$10K+", tags: ["Tech", "Review", "YouTube"], deadline: "Jul 12", symbol: "bolt.fill", colors: [0x396AFC, 0x2948FF], spotsLeft: 1)
    ]
}
