//
//  PrivacySecurityView.swift
//  Wefluens
//

import SwiftUI

struct PrivacySecurityView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showActivity: Bool = true
    @State private var dataSharing: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                groupTitle(l10n.t(.privacyTitle))

                VStack(spacing: 0) {
                    privacyRow(
                        icon: "person.crop.circle.badge.xmark",
                        title: l10n.t(.privacyBlockedAccounts),
                        subtitle: l10n.t(.privacyBlockedAccountsSub)
                    )
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
                    privacyRow(
                        icon: "eye.fill",
                        title: l10n.t(.privacyVisibility),
                        subtitle: l10n.t(.privacyVisibilitySub)
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
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.privacyTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func groupTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .tracking(1)
            .padding(.leading, 4)
    }

    private func privacyRow(icon: String, title: String, subtitle: String) -> some View {
        NavigationLink {
            EmptyView()
        } label: {
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
