//
//  DeveloperPanelView.swift
//  WeConnect
//
//  The consolidated privileged panel, revealed only after the developer-mode
//  unlock (tap the version in About ~7×) AND for is_admin accounts. Holds the
//  existing user management plus the new Top Talent / Brands curation tools.
//  Internal/admin-only, so copy is English (not localized).
//

import SwiftUI

struct DeveloperPanelView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                section {
                    navRow(icon: "person.2.badge.gearshape", title: "User Management",
                           subtitle: "Ban, delete, or invite users") { AdminUsersView() }
                    rowDivider
                    navRow(icon: "star.circle", title: "Curate Top Talent",
                           subtitle: "Feature & order creators") { CurateTalentView() }
                    rowDivider
                    navRow(icon: "building.2.crop.circle", title: "Manage Brands",
                           subtitle: "Create, edit, feature brands") { ManageBrandsView() }
                    rowDivider
                    navRow(icon: "megaphone.fill", title: "Manage Campaigns",
                           subtitle: "Publish, edit, delete open campaigns") { ManageCampaignsView() }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 4)
            .cardStyle()
    }

    private var rowDivider: some View {
        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
    }

    private func navRow<Destination: View>(icon: String, title: String, subtitle: String,
                                           @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 36, height: 36)
                    .background(Theme.coral.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
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
}
