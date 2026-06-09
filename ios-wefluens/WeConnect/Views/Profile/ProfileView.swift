//
//  ProfileView.swift
//  WeConnect
//
//  "Me" tab — shows authenticated user profile or a fallback.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var notificationsOn: Bool = true
    @State private var availableForDeals: Bool = true

    private var user: UserProfile {
        data.profile ?? UserProfile(
            name: auth.userEmail ?? "User",
            handle: "",
            role: "",
            bio: "",
            location: "",
            followers: "0",
            engagement: "0%",
            deals: "0",
            isAdmin: false
        )
    }

    private var initials: String {
        let parts = user.name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileCard
                    stats
                    availabilityCard
                    qrCodeBanner
                    settingsGroup
                    if auth.isAdmin {
                        adminGroup
                    }
                    supportGroup
                    signOut
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await data.refreshProfile()
            }
            .refreshable {
                await data.refreshProfile()
            }
        }
    }

    private var profileCard: some View {
        ZStack(alignment: .top) {
            Theme.dusk
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(spacing: 12) {
                userAvatar
                    .overlay(Circle().stroke(Theme.paper(for: colorScheme), lineWidth: 5))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                VStack(spacing: 4) {
                    Text(user.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Text(user.role.isEmpty ? (auth.userEmail ?? "") : user.role)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }

                if auth.isAdmin {
                    HStack(spacing: 5) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11, weight: .bold))
                        Text(l10n.t(.adminBadge))
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.coral)
                    .clipShape(Capsule())
                    .shadow(color: Theme.coral.opacity(0.35), radius: 8, y: 3)
                }

                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)
                }

                if !user.location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 12))
                        Text(user.location)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }

                NavigationLink {
                    EditProfileView()
                } label: {
                    Text(l10n.t(.profileEdit))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(20)
            .padding(.top, 56)
            .background(Theme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            .padding(.top, 64)
        }
    }

    // MARK: - Avatar (cloud-aware, unified through the Avatar component)

    private var userAvatar: some View {
        Avatar(
            colors: [0xFF4D6D, 0xFF9A5A],
            initials: initials,
            imageURL: user.avatarUrl,
            size: 92,
            isOnline: true
        )
    }

    private var stats: some View {
        HStack(spacing: 0) {
            statItem(value: user.followers, label: l10n.t(.profileReach))
            divider
            statItem(value: user.engagement, label: l10n.t(.profileEngagement))
            divider
            statItem(value: user.deals, label: l10n.t(.profileDeals))
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
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    private var availabilityCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.badge.checkmark.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.sunset)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.profileOpenDeals))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(l10n.t(.profileOpenDealsSub))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            Spacer()
            Toggle("", isOn: $availableForDeals)
                .labelsHidden()
                .tint(Theme.coral)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - QR Code Banner

    private var qrCodeBanner: some View {
        NavigationLink {
            QRCodeView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "qrcode")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Theme.plum)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Friends via QR")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Text("Scan or share your QR code")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var settingsGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            groupTitle(l10n.t(.profilePreferences))
            VStack(spacing: 0) {
                toggleRow(icon: "bell.fill", title: l10n.t(.profileNotifications), isOn: $notificationsOn)
                rowDivider
                NavigationLink {
                    SettingsView()
                } label: {
                    settingRowContent(icon: "globe", title: l10n.t(.profileLanguage))
                }
                .buttonStyle(.plain)
                rowDivider
                NavigationLink {
                    PrivacySecurityView()
                } label: {
                    settingRowContent(icon: "lock.fill", title: l10n.t(.profilePrivacy))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .cardStyle()
        }
    }

    private var adminGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            groupTitle("ADMIN")
            NavigationLink {
                AdminUsersView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .frame(width: 36, height: 36)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    Text(l10n.t(.adminTitle))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .cardStyle()
        }
    }

    private var supportGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            groupTitle(l10n.t(.profileSupport))
            VStack(spacing: 0) {
                fakeRow(icon: "questionmark.circle.fill", title: l10n.t(.profileHelp))
                rowDivider
                fakeRow(icon: "envelope.fill", title: l10n.t(.profileContact))
                rowDivider
                fakeRow(icon: "star.fill", title: l10n.t(.profileRate))
            }
            .padding(.vertical, 4)
            .cardStyle()
        }
    }

    private var signOut: some View {
        Button {
            Task { await auth.signOut() }
        } label: {
            Text(l10n.t(.profileSignOut))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .cardStyle()
        }
    }

    private func groupTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .tracking(1)
            .padding(.leading, 4)
    }

    private var rowDivider: some View {
        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 64)
    }

    private func fakeRow(icon: String, title: String) -> some View {
        Button {
        } label: {
            settingRowContent(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func settingRowContent(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink(for: colorScheme))
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
    ProfileView()
        .environment(AuthManager())
        .environment(LocalizationManager())
        .environment(AppDataService(userId: nil))
}
