//
//  WeConnectApp.swift
//  WeConnect
//

import SwiftUI

@main
struct WeConnectApp: App {
    // Receives APNs device-token callbacks for PushService (SwiftUI App has no
    // equivalent hook). See PushService / AppDelegate.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var localization = LocalizationManager()
    @State private var theme = ThemeManager()
    @State private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(localization)
                .environment(theme)
                .environment(auth)
                .preferredColorScheme(theme.mode.colorScheme)
        }
    }
}
