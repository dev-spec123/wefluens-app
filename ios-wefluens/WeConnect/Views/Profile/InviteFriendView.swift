//
//  InviteFriendView.swift
//  WeConnect
//
//  A user's personal, shareable invite code (Wefluens is invite-only). Fetches /
//  mints the caller's code via get_or_create_my_invite_code, shows how many uses
//  are left, and offers Copy + Share. Admins can revoke any code from the
//  Developer panel's Invite Codes screen.
//

import SwiftUI
import UIKit

struct InviteFriendView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var codeInfo: MyInviteCodeRow?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var toast: String?

    private var shareText: String {
        guard let c = codeInfo else { return "" }
        return "\(l10n.t(.inviteFriendShareMessage)) \(c.code)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper(for: colorScheme).ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(Theme.coral).scaleEffect(1.1)
                } else if let c = codeInfo {
                    content(c)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        Text(l10n.t(.addFriendError))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    }
                }

                if let toast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(Theme.ink(for: colorScheme).opacity(0.92)).clipShape(Capsule())
                            .padding(.bottom, 30).transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(l10n.t(.inviteFriendTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t(.settingsDone)) { dismiss() }.foregroundStyle(Theme.coral)
                }
            }
            .task { await load() }
        }
    }

    private func content(_ c: MyInviteCodeRow) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.coral)
                .padding(.top, 24)

            Text(l10n.t(.inviteFriendIntro))
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 8) {
                Text(c.code)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .tracking(2)
                Text("\(max(0, c.maxUses - c.uses)) \(l10n.t(.inviteFriendRemaining))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(Theme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = c.code
                    UISelectionFeedbackGenerator().selectionChanged()
                    show(l10n.t(.inviteFriendCopied))
                } label: {
                    pill(icon: "doc.on.doc", text: l10n.t(.inviteFriendCopy), filled: false)
                }
                .buttonStyle(.plain)

                ShareLink(item: shareText) {
                    pill(icon: "square.and.arrow.up", text: l10n.t(.inviteFriendShare), filled: true)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func pill(icon: String, text: String, filled: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
            Text(text).font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(filled ? .white : Theme.coral)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(filled ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.coral.opacity(0.12)))
        .clipShape(Capsule())
    }

    @MainActor
    private func load() async {
        do { codeInfo = try await data.getOrCreateMyInviteCode(); loadFailed = false }
        catch { print("⚠️ my invite code failed: \(error)"); loadFailed = true; codeInfo = nil }
        isLoading = false
    }

    private func show(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }
}
