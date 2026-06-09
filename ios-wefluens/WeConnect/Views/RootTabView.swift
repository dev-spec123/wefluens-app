//
//  RootTabView.swift
//  WeConnect
//
//  Root container with a native bottom tab bar (WeChat-style).
//

import SwiftUI

enum AppTab: Int, CaseIterable {
    case chats, contacts, discover, me

    var titleKey: L10n {
        switch self {
        case .chats: return .tabChats
        case .contacts: return .tabContacts
        case .discover: return .tabDiscover
        case .me: return .tabMe
        }
    }

    var icon: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .contacts: return "person.2.fill"
        case .discover: return "sparkles"
        case .me: return "person.crop.circle.fill"
        }
    }
}

struct RootTabView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(ThemeManager.self) private var theme
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: AppTab = .chats

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            ChatsListView()
                .tabItem { Label(l10n.t(AppTab.chats.titleKey), systemImage: AppTab.chats.icon) }
                .badge(data.totalUnread)
                .tag(AppTab.chats)

            ContactsView()
                .tabItem { Label(l10n.t(AppTab.contacts.titleKey), systemImage: AppTab.contacts.icon) }
                .tag(AppTab.contacts)

            DiscoverView()
                .tabItem { Label(l10n.t(AppTab.discover.titleKey), systemImage: AppTab.discover.icon) }
                .tag(AppTab.discover)

            ProfileView()
                .tabItem { Label(l10n.t(AppTab.me.titleKey), systemImage: AppTab.me.icon) }
                .tag(AppTab.me)
        }
        .tint(Theme.coral)
        .task { await data.observeInbox() }
    }

    /// Configures a clean, opaque WeChat-style bottom tab bar with a top hairline.
    /// The background / hairline / unselected-item colors are **dynamic** UIColors
    /// that resolve per trait, so the bar follows light↔dark automatically. The app
    /// drives the window's interface style via `.preferredColorScheme`, and UIKit
    /// re-resolves these colors on every trait change — the old version baked in
    /// `.light` colors, leaving the bar stuck bright in dark mode.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = dynamicColor { Theme.card(for: $0) }
        appearance.shadowColor = dynamicColor { Theme.ink(for: $0).opacity(0.08) }

        let selected = UIColor(Theme.coral)
        let normal = dynamicColor { Theme.inkSecondary(for: $0) }

        let item = appearance.stackedLayoutAppearance
        item.selected.iconColor = selected
        item.selected.titleTextAttributes = [.foregroundColor: selected]
        item.normal.iconColor = normal
        item.normal.titleTextAttributes = [.foregroundColor: normal]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// Builds a trait-aware UIColor from a scheme-keyed SwiftUI `Color` provider.
    /// Both resolutions are computed up front (on the main actor, at configure time)
    /// so the dynamic closure only branches between two ready UIColors — it never
    /// touches main-actor state on whatever thread UIKit resolves the color from.
    private static func dynamicColor(_ provider: (ColorScheme) -> Color) -> UIColor {
        let light = UIColor(provider(.light))
        let dark = UIColor(provider(.dark))
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    }
}

#Preview {
    RootTabView()
        .environment(LocalizationManager())
        .environment(ThemeManager())
}
