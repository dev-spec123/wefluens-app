//
//  ContactDetailView.swift
//  Wefluens
//

import SwiftUI

struct ContactDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let contact: Contact
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                stats
                actions
                infoCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(.leading, 18)
            .padding(.top, 8)
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, size: 96, isOnline: contact.isOnline)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            VStack(spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(contact.handle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            TagChip(text: contact.role, filled: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.top, 40)
        .background(
            Theme.dusk.opacity(colorScheme == .dark ? 0.2 : 0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var stats: some View {
        HStack(spacing: 0) {
            statItem(value: contact.followers, label: l10n.t(.contactDetailFollowers))
            divider
            statItem(value: contact.platform, label: l10n.t(.contactDetailPlatform))
            divider
            statItem(value: contact.isOnline ? l10n.t(.contactDetailOnline) : l10n.t(.contactDetailAway), label: l10n.t(.contactDetailStatus))
        }
        .padding(.vertical, 18)
        .cardStyle()
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline(for: colorScheme)).frame(width: 1, height: 36)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                Label(l10n.t(.contactDetailMessage), systemImage: "bubble.left.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.sunset)
                    .clipShape(Capsule())
                    .shadow(color: Theme.coral.opacity(0.35), radius: 12, y: 6)
            }

            Button {
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 52, height: 52)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.t(.contactDetailDetails))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink(for: colorScheme))
            infoRow(icon: "at", title: l10n.t(.contactDetailHandle), value: contact.handle)
            infoRow(icon: "person.crop.circle", title: l10n.t(.contactDetailRole), value: contact.role)
            infoRow(icon: "chart.bar.fill", title: l10n.t(.contactDetailAudience), value: "\(contact.followers) on \(contact.platform)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 38, height: 38)
                .background(Theme.coral.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(contact: SampleData.contacts[0])
            .environment(LocalizationManager())
    }
}
