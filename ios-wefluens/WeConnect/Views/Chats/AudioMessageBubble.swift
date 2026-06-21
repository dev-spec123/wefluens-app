//
//  AudioMessageBubble.swift
//  WeConnect
//
//  Renders a voice message as a compact bubble: a play/pause button, a simple
//  static waveform, and the clip duration. Loads a short-lived signed URL for the
//  private `chat-media` object, downloads it once to a temp file, and plays it via
//  AVAudioPlayer. Matches the other bubbles' look (Theme.sunset for mine, paper
//  card for theirs). Internal (not private) so both the 1:1 and group chats reuse it.
//

import SwiftUI
import AVFoundation

struct AudioMessageBubble: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    let path: String
    let isMe: Bool

    @State private var player: AudioBubblePlayer = AudioBubblePlayer()
    @State private var preparedURL: URL?
    @State private var isLoading = false
    @State private var didFail = false

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// A handful of fixed bar heights so the waveform reads as audio without
    /// needing real sample analysis (kept lightweight, deterministic per render).
    private let barHeights: [CGFloat] = [8, 14, 20, 11, 24, 16, 9, 18, 13, 22, 10, 17, 7, 19, 12]

    private var tint: Color {
        isMe ? .white : Theme.ink(for: colorScheme)
    }

    private var durationText: String {
        let total = player.duration > 0 ? player.duration : 0
        let secs = Int(total.rounded())
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isMe ? Color.white.opacity(0.22) : Theme.coral.opacity(0.14))
                    if isLoading {
                        ProgressView().tint(isMe ? .white : Theme.coral)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isMe ? .white : Theme.coral)
                    }
                }
                .frame(width: 36, height: 36)

                HStack(spacing: 3) {
                    ForEach(Array(barHeights.enumerated()), id: \.offset) { _, h in
                        Capsule()
                            .fill(tint.opacity(0.8))
                            .frame(width: 3, height: h)
                    }
                }
                .frame(height: 24)

                Text(durationText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isMe ? .white.opacity(0.9) : Theme.inkSecondary(for: colorScheme))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMe
                        ? AnyShapeStyle(Theme.sunset)
                        : AnyShapeStyle(colorScheme == .dark ? Theme.card(for: .dark) : Color(hex: 0xF0EBE4)))
            .clipShape(shape)
            .shadow(color: isMe ? Theme.coral.opacity(0.25) : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                    radius: isMe ? 6 : 3, y: isMe ? 3 : 1)
        }
        .buttonStyle(.plain)
        .task(id: path) {
            // Preload the duration so the bubble shows the clip length before play.
            await prepare()
        }
        .onDisappear { player.stop() }
    }

    /// Toggles playback: prepares (download + signed URL) on first tap, then plays
    /// or pauses. Never throws — failures just leave the button idle.
    private func toggle() {
        if player.isPlaying {
            player.pause()
            return
        }
        Task {
            if preparedURL == nil { await prepare() }
            guard let url = preparedURL else { return }
            player.play(url: url)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    /// Downloads the private audio object once (cached as `preparedURL`) and loads
    /// it into the player so the duration is known. Idempotent + guarded.
    private func prepare() async {
        guard preparedURL == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let signed = try await data.signedChatImageURL(path: path)
            let (tmp, _) = try await URLSession.shared.download(from: signed)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString.lowercased()).m4a")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            preparedURL = dest
            player.load(url: dest)
        } catch {
            didFail = true
            print("⚠️ voice playback prepare failed: \(error)")
        }
    }
}

/// Thin AVAudioPlayer wrapper that publishes `isPlaying` + `duration` for the
/// bubble. MainActor-isolated; the delegate callback hops back to the main actor.
@Observable
@MainActor
final class AudioBubblePlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0

    private var avPlayer: AVAudioPlayer?

    /// Loads a local file to expose its duration without starting playback.
    func load(url: URL) {
        if avPlayer == nil {
            avPlayer = try? AVAudioPlayer(contentsOf: url)
            avPlayer?.delegate = self
            avPlayer?.prepareToPlay()
        }
        duration = avPlayer?.duration ?? 0
    }

    func play(url: URL) {
        if avPlayer == nil {
            avPlayer = try? AVAudioPlayer(contentsOf: url)
            avPlayer?.delegate = self
        }
        // Make sure we can be heard even if the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        duration = avPlayer?.duration ?? 0
        avPlayer?.play()
        isPlaying = true
    }

    func pause() {
        avPlayer?.pause()
        isPlaying = false
    }

    func stop() {
        avPlayer?.stop()
        avPlayer?.currentTime = 0
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.avPlayer?.currentTime = 0
        }
    }
}
