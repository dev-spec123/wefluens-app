//
//  WefluensApp.swift
//  Wefluens
//

import SwiftUI

@main
struct WefluensApp: App {
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
