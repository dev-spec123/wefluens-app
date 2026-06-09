//
//  WeConnectApp.swift
//  WeConnect
//

import SwiftUI

@main
struct WeConnectApp: App {
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
