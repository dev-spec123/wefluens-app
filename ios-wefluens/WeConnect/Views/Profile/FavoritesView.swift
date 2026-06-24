//
//  FavoritesView.swift
//  WeConnect
//
//  收藏 — the on-device list of messages I've favorited from a 1:1 or group chat.
//  Reached from the "Me" tab → Favorites. Mirrors the BlockedAccountsView layout
//  (ScrollView + card + per-row divider) so it feels native to the rest of the app.
//  Backed by AppDataService.favorites (an @Observable FavoritesStore), so adding /
//  removing a favorite updates this list live.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    private var favorites: [Favorite] { data.favorites.list() }

    var body: some View {
        Group {
            if favorites.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.favoritesTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(favorites.enumerated()), id: \.element.id) { index, favorite in
                    row(favorite)
                    if index < favorites.count - 1 {
                        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 62)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
    }

    private func row(_ favorite: Favorite) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: favorite.kind))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 36, height: 36)
                .background(Theme.coral.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.sender)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
                Text(favorite.text)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(favorite.kind == "file" ? 1 : 3)
                    .multilineTextAlignment(.leading)
                Text(AppDataService.relativeTime(from: favorite.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }

            Spacer(minLength: 8)

            Button {
                remove(favorite)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.favoritesEmpty))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// SF Symbol matching the favorited message kind.
    private func icon(for kind: String) -> String {
        switch kind {
        case "image": return "photo"
        case "video": return "video"
        case "file": return "doc"
        case "audio": return "waveform"
        default: return "text.bubble"
        }
    }

    private func remove(_ favorite: Favorite) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.2)) {
            data.favorites.remove(id: favorite.id)
        }
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environment(LocalizationManager())
            .environment(AppDataService(userId: nil))
    }
}
