//
//  PrivacySecurityView.swift
//  WeConnect
//

import SwiftUI

struct PrivacySecurityView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var profileVisible: Bool = true
    @State private var showActivity: Bool = true
    @State private var dataSharing: Bool = false
    @State private var showChangePassword: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                groupTitle(l10n.t(.privacyTitle))

                VStack(spacing: 0) {
                    actionRow(
                        icon: "lock.rotation",
                        title: l10n.t(.forcePwChangePassword),
                        subtitle: l10n.t(.forcePwSubtitleOptional)
                    ) {
                        showChangePassword = true
                    }
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
                    NavigationLink {
                        BlockedAccountsView()
                    } label: {
                        rowContent(
                            icon: "person.crop.circle.badge.xmark",
                            title: l10n.t(.privacyBlockedAccounts),
                            subtitle: l10n.t(.privacyBlockedAccountsSub)
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
                    toggleRow(
                        icon: "eye.fill",
                        title: l10n.t(.privacyVisibility),
                        subtitle: l10n.t(.privacyVisibilitySub),
                        isOn: $profileVisible
                    )
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
                    toggleRow(
                        icon: "bolt.fill",
                        title: l10n.t(.privacyActivityStatus),
                        subtitle: l10n.t(.privacyActivityStatusSub),
                        isOn: $showActivity
                    )
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
                    toggleRow(
                        icon: "arrow.triangle.branch",
                        title: l10n.t(.privacyDataSharing),
                        subtitle: l10n.t(.privacyDataSharingSub),
                        isOn: $dataSharing
                    )
                }
                .padding(.vertical, 4)
                .cardStyle()

                groupTitle(l10n.t(.legalSafety))

                VStack(spacing: 0) {
                    NavigationLink {
                        LegalDocView(kind: .terms)
                    } label: {
                        rowContent(
                            icon: "doc.text",
                            title: l10n.t(.legalTerms),
                            subtitle: ""
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
                    NavigationLink {
                        LegalDocView(kind: .guidelines)
                    } label: {
                        rowContent(
                            icon: "checkmark.shield",
                            title: l10n.t(.legalGuidelines),
                            subtitle: ""
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .cardStyle()
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.privacyTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChangePassword) {
            ForcePasswordChangeView(forced: false)
        }
    }

    private func actionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconBadge(icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Shared row body (icon + title + optional subtitle + chevron) used by the
    /// NavigationLink rows. Subtitle is hidden when empty.
    private func rowContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func groupTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .tracking(1)
            .padding(.leading, 4)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.coral)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func iconBadge(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.coral)
            .frame(width: 36, height: 36)
            .background(Theme.coral.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

#Preview {
    PrivacySecurityView()
        .environment(LocalizationManager())
}
