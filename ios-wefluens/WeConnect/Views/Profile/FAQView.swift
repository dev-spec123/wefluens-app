//
//  FAQView.swift
//  WeConnect
//
//  Static Help & FAQ screen, pushed from Profile → Help & FAQ. Mirrors
//  LegalDocView's layout (localized title, English body copy). For anything not
//  answered here, the user taps Contact Support (SupportContactView).
//

import SwiftUI

struct FAQView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme

    private struct QA: Identifiable {
        let id = UUID()
        let q: String
        let a: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(l10n.t(.faqTitle))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))

                ForEach(Self.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.q)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.ink(for: colorScheme))
                        Text(item.a)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.faqTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static let items: [QA] = [
        QA(q: "How do I add a friend?",
           a: "Open the Contacts tab and tap Add Friend, then search by email, @handle, or name and send a request. You can also browse the Top Talent directory and add creators from there. The other person has to accept before you become contacts."),
        QA(q: "What's the difference between Brands and Campaigns?",
           a: "A brand is a company; a campaign is a single paid collaboration that a brand is hiring for. In Discover, tapping a brand filters the campaign list to that brand. The Brands directory in Contacts lets you browse brands and see each one's open campaigns."),
        QA(q: "How do favorites work?",
           a: "Long-press any message and choose Favorite to save it. Your favorites sync to your account, so they're available on any device you sign in to. Find them under Me → Favorites."),
        QA(q: "Will I get notifications?",
           a: "You can turn Push Notifications on under Me → Preferences. When enabled, the app asks for permission to send you alerts about new messages and friend requests."),
        QA(q: "Who can see when I'm active?",
           a: "Control this with the Activity Status switch in Privacy & Security. Turn it off and others won't see your online indicator. Data Sharing, in the same place, controls whether you appear in the Top Talent directory."),
        QA(q: "How do I report or block someone?",
           a: "Tap Report on any message, chat, or profile to flag it for our safety team — reports are reviewed within 24 hours. You can also Block a user so they can no longer contact you. Manage blocked users in Privacy & Security."),
        QA(q: "How do I change my password or delete my account?",
           a: "Both are in Me → Privacy & Security. Change Password lets you set a new one anytime; Delete Account permanently removes your profile and data."),
        QA(q: "Still need help?",
           a: "Tap Contact Support from the Me tab to send us a message — we'll get back to you by email."),
    ]
}
