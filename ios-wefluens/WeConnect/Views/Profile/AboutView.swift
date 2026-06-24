//
//  AboutView.swift
//  WeConnect
//
//  App identity + version + legal links. Pushed from the Profile → About row.
//  (Native iOS has no OTA/"check for update" — updates come via the App Store.)
//

import SwiftUI

struct AboutView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.coral)
                    Text("Wefluens Connect")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Text("\(l10n.t(.aboutVersion)) \(version)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)

                VStack(spacing: 0) {
                    NavigationLink {
                        LegalDocView(kind: .terms)
                    } label: {
                        row(l10n.t(.legalTerms))
                    }
                    Divider().padding(.leading, 16)
                    NavigationLink {
                        LegalDocView(kind: .guidelines)
                    } label: {
                        row(l10n.t(.legalGuidelines))
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.aboutTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
