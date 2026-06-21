//
//  MessageCache.swift
//  WeConnect
//
//  On-device cache of a conversation's recent messages, so opening a chat shows
//  the last view instantly (and survives a brief offline moment) before the live
//  data refreshes. One JSON file per conversation under the Caches directory —
//  mirrors the FavoritesStore / PinnedMessageStore JSON style, but file-backed
//  (a message list is far larger than the tiny prefs kept in UserDefaults).
//
//  Composes with the on-device media cache: cached messages store the media
//  `imagePath` (the stable storage path), so images load from disk by path too.
//

import Foundation

enum MessageCache {
    /// Keep only the most recent messages per conversation, bounding disk use.
    private static let maxCached = 200

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("wf-msgcache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func file(_ key: String) -> URL {
        dir.appendingPathComponent("\(key).json")
    }

    private static func load<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: file(key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: file(key), options: .atomic)
        }
    }

    // MARK: - 1:1 threads

    static func loadDM(_ threadId: UUID) -> [ChatMessage]? {
        load("dm-\(threadId.uuidString)", as: [ChatMessage].self)
    }

    static func saveDM(_ threadId: UUID, _ messages: [ChatMessage]) {
        save(Array(messages.suffix(maxCached)), key: "dm-\(threadId.uuidString)")
    }

    // MARK: - Group threads

    static func loadGroup(_ groupId: UUID) -> [GroupChatMessage]? {
        load("group-\(groupId.uuidString)", as: [GroupChatMessage].self)
    }

    static func saveGroup(_ groupId: UUID, _ messages: [GroupChatMessage]) {
        save(Array(messages.suffix(maxCached)), key: "group-\(groupId.uuidString)")
    }

    /// Wipes every cached conversation. Called on sign-out so a different account
    /// on the same device can't see the previous user's chats.
    static func clear() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
