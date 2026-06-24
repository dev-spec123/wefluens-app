//
//  DeveloperMode.swift
//  WeConnect
//
//  In-memory unlock for the hidden developer/admin panel. Tapping the version in
//  About ~7 times flips `unlocked` on for the rest of the session (resets on
//  relaunch). This only reveals the panel UI — every privileged action is still
//  gated server-side by is_admin, so unlocking on a non-admin account does nothing.
//

import Foundation

@Observable
@MainActor
final class DeveloperMode {
    private(set) var unlocked = false

    private var taps = 0
    private var lastTap = Date.distantPast
    private static let tapsToUnlock = 7

    /// Call on each tap of the version label. Counts rapid consecutive taps; a
    /// pause of >2s resets the counter. Reaching the threshold unlocks.
    func registerVersionTap() {
        let now = Date()
        if now.timeIntervalSince(lastTap) > 2 { taps = 0 }
        lastTap = now
        taps += 1
        if taps >= Self.tapsToUnlock {
            unlocked = true
            taps = 0
        }
    }

    func lock() { unlocked = false }
}
