//
//  BlockedAccountsView.swift
//  WeConnect
//
//  Trust & Safety: lists the accounts I've blocked and lets me unblock them.
//  Reached from Privacy & Security → Blocked Accounts.
//

import SwiftUI

struct BlockedAccountsView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var blocked: [Contact] = []
    @State private var isLoading = true
    @State private var unblocking: Set<UUID> = []
    @State private var showError = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(Theme.coral)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blocked.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.privacyBlockedAccounts))
        .navigationBarTitleDisplayMode(.inline)
        .alert(l10n.t(.blockError), isPresented: $showError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .task { await load() }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(blocked.enumerated()), id: \.element.id) { index, contact in
                    row(contact)
                    if index < blocked.count - 1 {
                        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 76)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
    }

    private func row(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                if !contact.handle.isEmpty {
                    Text(contact.handle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                unblock(contact)
            } label: {
                Group {
                    if unblocking.contains(contact.id) {
                        ProgressView().tint(Theme.coral)
                    } else {
                        Text(l10n.t(.unblockAction))
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(Theme.coral)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.coral.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(unblocking.contains(contact.id))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.blockedEmptyTitle))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Text(l10n.t(.blockedEmptySub))
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        isLoading = true
        blocked = await data.loadBlockedContacts()
        isLoading = false
    }

    private func unblock(_ contact: Contact) {
        guard !unblocking.contains(contact.id) else { return }
        unblocking.insert(contact.id)
        Task {
            do {
                try await data.unblockUser(contact.id)
                blocked.removeAll { $0.id == contact.id }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                showError = true
                print("⚠️ unblock failed: \(error)")
            }
            unblocking.remove(contact.id)
        }
    }
}
