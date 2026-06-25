//
//  VoiceRecorder.swift
//  WeConnect
//
//  Small tap-to-toggle voice recorder for chat voice messages. Requests mic
//  permission, configures the audio session for record + playback, captures to a
//  temporary `.m4a` (AAC), and returns the encoded `Data` on stop. All failures
//  are handled gracefully (no crashes) so the composer can fall back silently.
//

import Foundation
import AVFoundation

/// Drives a single tap-to-toggle recording. The view observes `isRecording` to
/// show the inline recording indicator and `elapsed` to render the duration.
/// MainActor isolated to match the app's default actor isolation.
@Observable
@MainActor
final class VoiceRecorder {
    /// True while a recording is in progress (drives the inline recording indicator).
    private(set) var isRecording = false
    /// Seconds elapsed in the current recording (drives the duration label).
    private(set) var elapsed: TimeInterval = 0
    /// Set to true after `start()` if microphone permission was denied, so the
    /// composer can surface a one-time "enable mic in Settings" alert.
    var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var timerTask: Task<Void, Never>?

    /// Requests mic permission (if needed), configures the audio session, and
    /// begins recording to a temp `.m4a`. Returns true when recording actually
    /// started. On any failure it cleans up and returns false (never throws).
    @discardableResult
    func start() async -> Bool {
        guard !isRecording else { return false }

        let granted = await Self.requestPermission()
        guard granted else {
            permissionDenied = true
            return false
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("⚠️ voice: audio session setup failed: \(error)")
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString.lowercased()).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            guard rec.record() else {
                print("⚠️ voice: recorder failed to start")
                return false
            }
            recorder = rec
            fileURL = url
            isRecording = true
            elapsed = 0
            startTimer()
            return true
        } catch {
            print("⚠️ voice: recorder init failed: \(error)")
            return false
        }
    }

    /// Stops recording and returns the encoded `.m4a` data. Returns nil if there
    /// was no active recording, the clip was too short (< 0.5s), or reading the
    /// file failed. Always tears down the session.
    func stopAndFetchData() -> Data? {
        guard isRecording, let recorder, let fileURL else {
            cleanup()
            return nil
        }
        let duration = elapsed
        recorder.stop()
        stopTimer()
        isRecording = false
        self.recorder = nil

        var data: Data?
        if duration >= 0.5 {
            data = try? Data(contentsOf: fileURL)
        }
        try? FileManager.default.removeItem(at: fileURL)
        self.fileURL = nil
        deactivateSession()
        return data
    }

    /// Cancels the current recording (e.g. the user slid away) without returning
    /// any data. Discards the temp file.
    func cancel() {
        recorder?.stop()
        stopTimer()
        isRecording = false
        recorder = nil
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        deactivateSession()
    }

    // MARK: - Private

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.isRecording else { return }
                self.elapsed += 0.1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func cleanup() {
        recorder = nil
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        isRecording = false
        stopTimer()
    }

    /// Bridges the callback-based permission API into async/await.
    private static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
