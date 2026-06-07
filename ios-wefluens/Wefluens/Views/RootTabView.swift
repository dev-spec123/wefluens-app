//
//  RootTabView.swift
//  Wefluens
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
        configureTabBarAppearance()
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
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.card(for: .light))
        appearance.shadowColor = UIColor(Theme.ink(for: .light)).withAlphaComponent(0.08)

        let selected = UIColor(Theme.coral)
        let normal = UIColor(Theme.inkSecondary(for: .light))

        let item = appearance.stackedLayoutAppearance
        item.selected.iconColor = selected
        item.selected.titleTextAttributes = [.foregroundColor: selected]
        item.normal.iconColor = normal
        item.normal.titleTextAttributes = [.foregroundColor: normal]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    RootTabView()
        .environment(LocalizationManager())
        .environment(ThemeManager())
}
