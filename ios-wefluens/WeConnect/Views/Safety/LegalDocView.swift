//
//  LegalDocView.swift
//  WeConnect
//
//  Trust & Safety: the in-app Terms of Use (EULA) and Community Guidelines.
//  Shown at sign-up (the agreement gate) and from Privacy & Security. The
//  Community Guidelines state a zero-tolerance policy for objectionable content
//  and abusive users, as required for user-generated-content apps (Guideline 1.2).
//

import SwiftUI

enum LegalDocKind {
    case terms
    case guidelines

    var titleKey: L10n {
        switch self {
        case .terms: return .legalTerms
        case .guidelines: return .legalGuidelines
        }
    }
}

/// One titled section of legal copy.
private struct LegalSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

struct LegalDocView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let kind: LegalDocKind
    /// True only when this view is presented modally (a sheet), where it needs its
    /// own dismiss control. When pushed onto a navigation stack the back chevron
    /// already handles dismissal, so the Done button would be redundant.
    var showsDoneButton: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(l10n.t(kind.titleKey))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(Self.lastUpdated)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.ink(for: colorScheme))
                        Text(section.body)
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
        .navigationTitle(l10n.t(kind.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.t(.settingsDone)) { dismiss() }
                        .foregroundStyle(Theme.coral)
                }
            }
        }
    }

    private var sections: [LegalSection] {
        kind == .terms ? Self.termsSections : Self.guidelinesSections
    }

    private static let lastUpdated = "Last updated: June 2026"
    private static let supportEmail = "support@wefluens.com"

    // MARK: - Terms of Use (EULA)

    private static let termsSections: [LegalSection] = [
        LegalSection(
            heading: "1. Acceptance",
            body: "Wefluens Connect (\"the App\") is a social platform where creators and brands connect, message, and collaborate. By creating an account or using the App you agree to these Terms of Use and to our Community Guidelines. If you do not agree, do not use the App."
        ),
        LegalSection(
            heading: "2. Eligibility",
            body: "You must be at least 17 years old and legally able to enter into this agreement to use the App. You are responsible for keeping your account credentials secure and for all activity under your account."
        ),
        LegalSection(
            heading: "3. Your content",
            body: "You retain ownership of the messages, images, and other content you submit. You are solely responsible for that content and grant Wefluens Connect a limited license to host and display it so the App can function (for example, delivering your messages to their recipients)."
        ),
        LegalSection(
            heading: "4. Zero tolerance for objectionable content and abuse",
            body: "There is no tolerance for objectionable, abusive, or illegal content or behavior on Wefluens Connect. By using the App you agree not to post or send such content and not to harass, threaten, or abuse other users. Violations may result in immediate content removal and account termination. See the Community Guidelines for details."
        ),
        LegalSection(
            heading: "5. Reporting and moderation",
            body: "The App provides tools to report objectionable content or users and to block abusive users. We review reports and act on them — typically within 24 hours — by removing offending content and ejecting users who violate these terms. You can report any message or user from the chat or profile screens, and manage blocked users in Privacy & Security."
        ),
        LegalSection(
            heading: "6. Account deletion",
            body: "You may delete your account at any time from Profile → Privacy & Security, which removes your profile and associated data. We may suspend or terminate accounts that violate these Terms."
        ),
        LegalSection(
            heading: "7. Disclaimer & contact",
            body: "The App is provided \"as is\" without warranties of any kind. Questions about these Terms can be sent to \(Self.supportEmail)."
        ),
    ]

    // MARK: - Community Guidelines

    private static let guidelinesSections: [LegalSection] = [
        LegalSection(
            heading: "Be respectful",
            body: "Wefluens Connect is a professional community for creators and brands. Treat others with respect. Harassment, bullying, hate speech, and threats are never allowed."
        ),
        LegalSection(
            heading: "No objectionable content",
            body: "Do not post or send content that is sexually explicit, violent, hateful, discriminatory, illegal, or that exploits or endangers anyone. This applies to text, images, files, and group chats. We have zero tolerance for this content and remove it as soon as we become aware of it."
        ),
        LegalSection(
            heading: "No spam or scams",
            body: "Don't send unsolicited bulk messages, deceptive offers, phishing links, or impersonate others."
        ),
        LegalSection(
            heading: "Report and block",
            body: "If you see something that breaks these guidelines, tap Report on the message, chat, or profile. You can also Block a user so they can no longer contact you or see your content. Reports are confidential and reviewed within 24 hours."
        ),
        LegalSection(
            heading: "Enforcement",
            body: "Content that violates these guidelines is removed, and users who violate them may be suspended or permanently removed from Wefluens Connect. Serious violations are reported to the appropriate authorities. To reach our safety team, email \(Self.supportEmail)."
        ),
    ]
}
