//
//  PushService.swift
//  WeConnect
//
//  Client-side push notification scaffolding. This half is COMPLETE: it requests
//  OS permission, registers for remote notifications, turns the APNs token into a
//  hex string, and hands it to the data layer (which upserts it into device_tokens).
//
//  What it can't do yet: actually deliver pushes. That needs the server send path
//  in backend/functions/send-push (stubbed) plus an Apple Developer account to mint
//  the APNs Auth Key + enable the Push capability. Until that's filled in, tokens
//  are registered and stored, but no notification is ever sent. See PLAN.md →
//  "Push notifications" for the hand-off checklist.
//

import UIKit
import UserNotifications

@MainActor
final class PushService {
    static let shared = PushService()
    private init() {}

    /// Latest APNs device token (hex). Cached so a handler attached after the
    /// token already arrived still receives it (see `onToken`).
    private(set) var deviceToken: String?

    /// Set by the data layer to upload each (re)issued token. Invoked immediately
    /// with the cached token if one already exists when assigned.
    var onToken: ((String) -> Void)? {
        didSet { if let deviceToken { onToken?(deviceToken) } }
    }

    /// Current OS authorization status (authorized / denied / notDetermined).
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Prompts for permission (only the first time the OS shows it) and, if
    /// granted, registers for remote notifications. Returns whether we're
    /// authorized. Call this when the user opts IN via the toggle.
    @discardableResult
    func requestAuthorizationAndRegister() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    /// Re-registers (no prompt) when the user has already authorized — used at
    /// launch so a rotated token gets refreshed for opted-in users.
    func registerIfAuthorized() async {
        if await authorizationStatus() == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Called by the AppDelegate when APNs returns a token.
    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        onToken?(token)
    }

    func didFailToRegister(_ error: Error) {
        print("⚠️ APNs registration failed: \(error)")
    }
}

/// Minimal app delegate, wired in via @UIApplicationDelegateAdaptor purely to
/// receive the remote-notification token callbacks (SwiftUI's App type has no
/// equivalent). Forwards everything to PushService.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushService.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in PushService.shared.didFailToRegister(error) }
    }
}
