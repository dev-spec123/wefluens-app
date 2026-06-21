//
//  PinnedMessageStore.swift
//  WeConnect
//
//  Local-only pinned group messages (群公告), one per group. A pinned message is
//  saved on-device (never synced) to a UserDefaults JSON object keyed by groupId
//  so it survives relaunches. Mirrors the FavoritesStore / AppDataService prefs
//  pattern: a tiny JSON store, loaded once on init and rewritten on every change.
//
//  @Observable so the group chat banner appears / disappears the instant a
//  message is pinned or unpinned.
//

import Foundation

/// One pinned (群公告) message for a group. `id` is the original message's id so
/// the banner can scroll-to / dedupe; `text` is a single-line excerpt; `by` is the
/// pinner's display name (kept for a future "pinned by …" caption).
struct PinnedMessage: Codable, Equatable {
    let id: UUID
    let text: String
    let by: String
}

/// On-device pinned-message store. Persisted as a JSON object (groupId → entry)
/// under one UserDefaults key.
@Observable
final class PinnedMessageStore {
    /// Pinned message per group id (keyed by the group's UUID string).
    private(set) var pinned: [String: PinnedMessage] = [:]

    private static let storageKey = "wefluens.pinnedMessages"

    init() {
        pinned = Self.load()
    }

    // MARK: - API

    /// The pinned message for a group, or nil when nothing is pinned.
    func message(for groupId: UUID) -> PinnedMessage? {
        pinned[groupId.uuidString]
    }

    /// True when the given message id is the one currently pinned for the group.
    func isPinned(_ messageId: UUID, in groupId: UUID) -> Bool {
        pinned[groupId.uuidString]?.id == messageId
    }

    /// Pins a message for a group, replacing any previous pin. Persists immediately.
    func pin(_ message: PinnedMessage, in groupId: UUID) {
        pinned[groupId.uuidString] = message
        save()
    }

    /// Removes the pinned message for a group and persists.
    func unpin(in groupId: UUID) {
        pinned.removeValue(forKey: groupId.uuidString)
        save()
    }

    // MARK: - Persistence (JSON object in UserDefaults, mirrors AppDataService prefs)

    private static func load() -> [String: PinnedMessage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: PinnedMessage].self, from: data)
        else { return [:] }
        return decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pinned) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
