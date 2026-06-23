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
import AVKit

struct FavoritesView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var openMedia: FavMedia?
    @State private var shareItem: ShareItem?

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
        .fullScreenCover(item: $openMedia) { m in
            if m.kind == "image" {
                FavoriteImageViewer(path: m.path, data: data)
            } else {
                FavoriteMediaPlayer(path: m.path, ext: m.ext, data: data)
            }
        }
        .sheet(item: $shareItem) { item in
            FavoriteShareSheet(url: item.url)
        }
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
                    .lineLimit(3)
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
        .contentShape(Rectangle())
        .onTapGesture { open(favorite) }
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

    /// Opens a favorited media item: image → fullscreen viewer, video/audio →
    /// player, file → share sheet. Text favorites (no path) do nothing.
    private func open(_ favorite: Favorite) {
        guard let path = favorite.imagePath, !path.isEmpty else { return }
        switch favorite.kind {
        case "image", "video", "audio":
            openMedia = FavMedia(path: path, kind: favorite.kind, ext: ext(for: favorite))
        case "file":
            Task {
                if let url = try? await data.cachedMediaFileURL(path: path, ext: ext(for: favorite)) {
                    shareItem = ShareItem(url: url)
                }
            }
        default:
            break
        }
    }

    /// Local-cache file extension to use for a favorited media kind.
    private func ext(for favorite: Favorite) -> String {
        switch favorite.kind {
        case "image": return "jpg"
        case "video": return "mp4"
        case "audio": return "m4a"
        case "file":
            if let n = favorite.fileName, let dot = n.lastIndex(of: "."), n.index(after: dot) < n.endIndex {
                return String(n[n.index(after: dot)...])
            }
            return "dat"
        default: return "dat"
        }
    }
}

// MARK: - Favorite media viewers

private struct FavMedia: Identifiable {
    let id = UUID()
    let path: String
    let kind: String
    let ext: String
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Fullscreen viewer for a favorited photo (loads the cached file).
private struct FavoriteImageViewer: View {
    let path: String
    let data: AppDataService
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image).resizable().scaledToFit().ignoresSafeArea()
            } else if failed {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.white.opacity(0.6))
            } else {
                ProgressView().tint(.white)
            }
            closeButton
        }
        .task {
            do {
                let url = try await data.cachedMediaFileURL(path: path, ext: "jpg")
                if let img = UIImage(contentsOfFile: url.path) { image = img } else { failed = true }
            } catch { failed = true }
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(.black.opacity(0.4), in: Circle())
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 8)
            Spacer()
        }
    }
}

/// Fullscreen AV player for a favorited video or voice clip.
private struct FavoriteMediaPlayer: View {
    let path: String
    let ext: String
    let data: AppDataService
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player).ignoresSafeArea()
            } else if failed {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.white.opacity(0.6))
            } else {
                ProgressView().tint(.white)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(.black.opacity(0.4), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 8)
                Spacer()
            }
        }
        .task {
            do {
                let url = try await data.cachedMediaFileURL(path: path, ext: ext)
                let p = AVPlayer(url: url); player = p; p.play()
            } catch { failed = true }
        }
        .onDisappear { player?.pause() }
    }
}

/// System share sheet for a favorited file (after it's fetched to the cache).
private struct FavoriteShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        FavoritesView()
            .environment(LocalizationManager())
            .environment(AppDataService(userId: nil))
    }
}
