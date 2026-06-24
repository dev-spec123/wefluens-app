//
//  ProfileView.swift
//  WeConnect
//
//  "Me" tab — shows authenticated user profile or a fallback.
//

import SwiftUI
import StoreKit
import UIKit

struct ProfileView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var notificationsOn: Bool = true
    /// Persisted locally (same key as the RN app's AsyncStorage) so the toggle
    /// survives relaunches instead of resetting to true every launch.
    @AppStorage("wefluens.openToDeals") private var availableForDeals: Bool = true
    @State private var showDeleteConfirm = false
    @State private var showContactSupport = false

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
                    favoritesRow
                    settingsGroup
                    if auth.isAdmin {
                        developerPanelGroup
                    }
                    supportGroup
                    signOut
                    deleteAccountButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .alert(l10n.t(.profileDeleteAccount), isPresented: $showDeleteConfirm) {
                Button(l10n.t(.adminCancel), role: .cancel) {}
                Button(l10n.t(.profileDeleteConfirm), role: .destructive) {
                    Task {
                        do {
                            try await data.deleteAccount()
                            await auth.signOut()
                        } catch {
                            print("⚠️ delete account failed: \(error)")
                        }
                    }
                }
            } message: {
                Text(l10n.t(.profileDeleteMessage))
            }
            .sheet(isPresented: $showContactSupport) {
                SupportContactView()
            }
            .task {
                await data.refreshProfile()
                notificationsOn = data.profile?.notificationsEnabled ?? true
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

    // MARK: - Favorites (promoted out of Preferences to a primary Me-tab row)

    private var favoritesRow: some View {
        NavigationLink {
            FavoritesView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Theme.sunset)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t(.favoritesTitle))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    Text(favoritesSubtitle)
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

    private var favoritesSubtitle: String {
        let count = data.favorites.list().count
        return count == 0 ? l10n.t(.favoritesEmpty) : "\(count)"
    }

    private var settingsGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            groupTitle(l10n.t(.profilePreferences))
            VStack(spacing: 0) {
                toggleRow(icon: "bell.fill", title: l10n.t(.profileNotifications), isOn: Binding(
                    get: { notificationsOn },
                    set: { newValue in
                        notificationsOn = newValue
                        Task { await handleNotificationsToggle(newValue) }
                    }
                ))
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

    private var developerPanelGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            groupTitle("Developer")
            NavigationLink {
                DeveloperPanelView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .frame(width: 36, height: 36)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    Text("Developer Panel")
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
                NavigationLink {
                    FAQView()
                } label: {
                    settingRowContent(icon: "questionmark.circle.fill", title: l10n.t(.profileHelp))
                }
                .buttonStyle(.plain)
                rowDivider
                actionRow(icon: "envelope.fill", title: l10n.t(.profileContact)) {
                    showContactSupport = true
                }
                rowDivider
                actionRow(icon: "star.fill", title: l10n.t(.profileRate)) {
                    requestAppReview()
                }
                rowDivider
                NavigationLink {
                    AboutView()
                } label: {
                    settingRowContent(icon: "info.circle.fill", title: l10n.t(.profileAbout))
                }
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

    /// Destructive self-service account deletion (App Store 5.1.1(v) requirement).
    private var deleteAccountButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Text(l10n.t(.profileDeleteAccount))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
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

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingRowContent(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notifications

    /// Handles a user tap on the Push Notifications toggle. Turning it on prompts
    /// for OS permission (first time) and registers the device; if the OS denies,
    /// the toggle reverts AND we deep-link to the system notification settings so
    /// the user can flip it back on (mirrors the RN app's `Linking.openSettings`).
    /// The preference is persisted to the profile either way.
    private func handleNotificationsToggle(_ on: Bool) async {
        if on {
            let granted = await PushService.shared.requestAuthorizationAndRegister()
            if granted {
                await data.setNotificationsEnabled(true)
            } else {
                notificationsOn = false
                await data.setNotificationsEnabled(false)
                openNotificationSettings()
            }
        } else {
            await data.setNotificationsEnabled(false)
        }
    }

    /// Opens this app's page in the system Settings app, where the user can grant
    /// notification permission. Equivalent to RN's `Linking.openSettings()`.
    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Support actions

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        SKStoreReviewController.requestReview(in: scene)
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
