//
//  ChatVideoBubble.swift
//  WeConnect
//
//  Video message bubble: a play tile that opens a fullscreen player. The video is
//  downloaded to the on-device cache ONCE (keyed by its storage path) and played
//  from the local copy, so re-watching costs no bandwidth — mirrors the image cache.
//  Shared by 1:1 (ChatDetailView) and group (GroupChatDetailView) chats.
//

import SwiftUI
import AVKit

struct ChatVideoBubble: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    let path: String
    let caption: String
    let isMe: Bool

    @State private var showPlayer = false
    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
            tile
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 15.5))
                    .foregroundStyle(isMe ? .white : Theme.ink(for: colorScheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe
                                ? AnyShapeStyle(Theme.sunset)
                                : AnyShapeStyle(colorScheme == .dark ? Theme.card(for: .dark) : Color(hex: 0xF0EBE4)))
                    .clipShape(shape)
            }
        }
    }

    // A dark tile with a centered play button + a small video badge. The video is
    // only downloaded when tapped (in the player) — showing the list costs nothing.
    private var tile: some View {
        ZStack {
            Theme.cardSubtle(for: colorScheme)
            Image(systemName: "play.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.35), radius: 5, y: 1)
            VStack {
                HStack {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.35), in: Circle())
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(width: 210, height: 158)
        .clipShape(shape)
        .overlay(shape.stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        .shadow(color: isMe ? Theme.coral.opacity(0.18) : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.05),
                radius: 5, y: 2)
        .contentShape(shape)
        .onTapGesture { showPlayer = true }
        .fullScreenCover(isPresented: $showPlayer) {
            VideoPlayerScreen(path: path, data: data)
        }
    }
}

/// Fullscreen video player. Resolves the local cached file via AppDataService
/// (downloaded once), plays with native AVKit controls, and offers a system
/// share/save action. AppDataService is passed in (not read from environment) so
/// it's reliably available inside the fullScreenCover presentation.
private struct VideoPlayerScreen: View {
    let path: String
    let data: AppDataService
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var localURL: URL?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    Spacer()
                    if let localURL {
                        ShareLink(item: localURL) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                Spacer()
            }
        }
        .task {
            do {
                let url = try await data.cachedMediaFileURL(path: path, ext: "mp4")
                localURL = url
                let p = AVPlayer(url: url)
                player = p
                p.play()
            } catch {
                failed = true
                print("⚠️ video load failed: \(error)")
            }
        }
        .onDisappear { player?.pause() }
    }
}
