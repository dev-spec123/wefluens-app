//
//  FavoritesStore.swift
//  WeConnect
//
//  Cloud-synced favorites (收藏) of chat messages, WeChat-style. Favorites live in
//  the Supabase `favorites` table (RLS: own rows) so they follow the account
//  across devices. An in-memory copy backs the synchronous list()/contains() the
//  UI uses; add()/remove() update it optimistically and persist to the cloud.
//
//  (Previously on-device only via UserDefaults — migrated to cloud sync.)
//
//  @Observable so the FavoritesView list refreshes the instant a favorite is
//  added or removed.
//

import Foundation
import Supabase

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
}

/// Cloud-backed favorites store. The source of truth is the `favorites` table;
/// `favorites` here is a synchronized in-memory cache for fast reads.
@Observable
@MainActor
final class FavoritesStore {
    /// Saved favorites, newest first (the order the list renders).
    private(set) var favorites: [Favorite] = []

    /// The signed-in user's id, set during data-service startup. Until set,
    /// add/remove no-op on the cloud (but still update memory) and loads are empty.
    @ObservationIgnored private var userId: UUID?

    init() {}

    /// Wires the store to the signed-in user. Call before loadFromCloud().
    func configure(userId: UUID?) {
        self.userId = userId
    }

    // MARK: - API

    /// All favorites, newest first.
    func list() -> [Favorite] { favorites }

    /// True when a message id is already saved (lets a menu show a checkmark / toggle).
    func contains(_ id: UUID) -> Bool {
        favorites.contains { $0.id == id }
    }

    /// Saves a message. Idempotent: re-favoriting the same id replaces the existing
    /// entry and re-sorts it to the top. Updates memory immediately, then persists.
    func add(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        favorites.insert(favorite, at: 0)
        guard let uid = userId else { return }
        Task {
            do {
                try await supabase.from("favorites")
                    .upsert(FavoriteUpsert(
                        user_id: uid.uuidString,
                        message_id: favorite.id.uuidString,
                        text: favorite.text,
                        kind: favorite.kind,
                        sender: favorite.sender,
                        source: favorite.source
                    ), onConflict: "user_id,message_id")
                    .execute()
            } catch {
                print("⚠️ favorite add failed: \(error)")
            }
        }
    }

    /// Removes a favorite by its message id (memory first, then the cloud).
    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        guard let uid = userId else { return }
        Task {
            do {
                try await supabase.from("favorites")
                    .delete()
                    .eq("user_id", value: uid.uuidString)
                    .eq("message_id", value: id.uuidString)
                    .execute()
            } catch {
                print("⚠️ favorite remove failed: \(error)")
            }
        }
    }

    // MARK: - Cloud load

    /// Loads favorites from the `favorites` table into the in-memory cache.
    func loadFromCloud() async {
        guard let uid = userId else { favorites = []; return }
        do {
            let rows: [FavoriteRow] = try await supabase
                .from("favorites")
                .select()
                .eq("user_id", value: uid.uuidString)
                .order("saved_at", ascending: false)
                .execute()
                .value
            favorites = rows.map {
                Favorite(id: $0.messageId, text: $0.text, kind: $0.kind,
                         sender: $0.sender, source: $0.source, date: $0.savedAt)
            }
        } catch {
            print("⚠️ favorites load failed: \(error)")
        }
    }
}
