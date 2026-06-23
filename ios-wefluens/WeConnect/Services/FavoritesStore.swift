//
//  FavoritesStore.swift
//  WeConnect
//
//  Local-only favorites (收藏) of chat messages, WeChat-style. A favorited message
//  is saved on-device (never synced) to a UserDefaults JSON array so it survives
//  relaunches. Mirrors the pin / mute / remark prefs pattern in AppDataService:
//  a tiny JSON store, loaded once on init and rewritten on every change.
//
//  @Observable so the FavoritesView list refreshes the instant a favorite is
//  added or removed.
//

import Foundation

/// One saved (收藏) message. `id` is the original message's id, so favoriting the
/// same message twice is idempotent (replace-in-place rather than duplicate).
/// `kind`/`source` are plain strings (e.g. "text"/"image", "dm"/"group") kept
/// human-readable for the list and future-proof against model changes.
struct Favorite: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let kind: String
    let sender: String
    let source: String
    let date: Date
    /// Storage path of the favorited media (image / video / audio / file), so the
    /// favorite can be re-opened or played from the list. nil for text favorites.
    /// Optional with a default → old persisted favorites still decode (key absent → nil).
    var imagePath: String? = nil
    var fileName: String? = nil
    var fileMime: String? = nil
}

/// On-device favorites store. Persisted as a JSON array under one UserDefaults key.
@Observable
final class FavoritesStore {
    /// Saved favorites, newest first (the order the list renders).
    private(set) var favorites: [Favorite] = []

    private static let storageKey = "wefluens.favorites"

    init() {
        favorites = Self.load()
    }

    // MARK: - API

    /// All favorites, newest first.
    func list() -> [Favorite] { favorites }

    /// True when a message id is already saved (lets a menu show a checkmark / toggle).
    func contains(_ id: UUID) -> Bool {
        favorites.contains { $0.id == id }
    }

    /// Saves a message. Idempotent: re-favoriting the same id replaces the existing
    /// entry and re-sorts it to the top. Persists immediately.
    func add(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        favorites.insert(favorite, at: 0)
        save()
    }

    /// Removes a favorite by its message id and persists.
    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence (JSON array in UserDefaults, mirrors AppDataService prefs)

    private static func load() -> [Favorite] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Favorite].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
