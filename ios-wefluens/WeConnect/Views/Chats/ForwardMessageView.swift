//
//  ForwardMessageView.swift
//  WeConnect
//
//  Multi-select target picker for forwarding a chat message. Lists my real
//  friends (the friendship graph) and the groups I belong to; tapping Send hands
//  the source + chosen targets to the `forward-message` edge function, which does
//  the server-side storage.copy + dual permission check and reuses the existing
//  send functions. This view never renders message bubbles — it only picks targets.
//

import SwiftUI

struct ForwardMessageView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// The message being forwarded (kind + id) — supplied by the long-press menu.
    let source: ForwardSource

    @State private var searchText: String = ""
    @State private var selectedFriendIDs: Set<UUID> = []
    @State private var selectedGroupIDs: Set<UUID> = []
    @State private var isSending: Bool = false
    @State private var showError: Bool = false

    /// My friends (same source as Contacts) and the groups I'm a member of.
    private var friends: [Contact] { data.contacts }
    private var groups: [Conversation] { data.conversations.filter { $0.isGroup } }

    private var filteredFriends: [Contact] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.handle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredGroups: [Conversation] {
        guard !searchText.isEmpty else { return groups }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var selectedFriends: [Contact] { friends.filter { selectedFriendIDs.contains($0.id) } }
    private var selectedGroups: [Conversation] { groups.filter { selectedGroupIDs.contains($0.id) } }

    private var totalSelected: Int { selectedFriendIDs.count + selectedGroupIDs.count }
    private var canSend: Bool { totalSelected > 0 && !isSending }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if totalSelected > 0 { selectedBar }
            content
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert(l10n.t(.forwardError), isPresented: $showError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .task {
            if data.contacts.isEmpty { await data.loadContacts() }
            if data.conversations.isEmpty { await data.loadConversations() }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.forwardTitle))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                if totalSelected > 0 {
                    Text("\(totalSelected) \(l10n.t(.createGroupSelected))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
            }

            Spacer()

            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var sendButton: some View {
        if isSending {
            ProgressView()
                .tint(Theme.coral)
                .frame(width: 44, height: 32)
        } else {
            Button(action: forward) {
                Text(l10n.t(.forwardSend))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSend ? Theme.coral : Theme.inkTertiary(for: colorScheme))
            }
            .disabled(!canSend)
        }
    }

    // MARK: - Selected chips

    private var selectedBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(selectedFriends) { contact in
                    chip(name: contact.name, colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, symbol: nil) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { _ = selectedFriendIDs.remove(contact.id) }
                    }
                }
                ForEach(selectedGroups) { group in
                    chip(name: group.name, colors: group.avatarColors, initials: nil, imageURL: nil, symbol: "person.3.fill") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { _ = selectedGroupIDs.remove(group.id) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.coral.opacity(colorScheme == .dark ? 0.12 : 0.06))
    }

    private func chip(name: String, colors: [UInt], initials: String?, imageURL: String?, symbol: String?, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Avatar(colors: colors, symbol: symbol, initials: initials, imageURL: imageURL, size: 28)
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(Theme.card(for: colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if friends.isEmpty && groups.isEmpty {
            if data.isLoadingContacts || data.isLoadingConversations {
                Spacer()
                ProgressView().tint(Theme.coral)
                Spacer()
            } else {
                emptyState
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    searchField
                    if !filteredFriends.isEmpty {
                        sectionHeader(l10n.t(.forwardFriends))
                        VStack(spacing: 0) {
                            ForEach(Array(filteredFriends.enumerated()), id: \.element.id) { index, contact in
                                targetButton(
                                    name: contact.name,
                                    subtitle: contact.role.isEmpty ? "@\(contact.handle)" : contact.role,
                                    colors: contact.avatarColors,
                                    initials: contact.initials,
                                    imageURL: contact.avatarUrl,
                                    symbol: nil,
                                    isOnline: contact.isOnline,
                                    isSelected: selectedFriendIDs.contains(contact.id)
                                ) { toggleFriend(contact.id) }
                                if index < filteredFriends.count - 1 { rowDivider }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    if !filteredGroups.isEmpty {
                        sectionHeader(l10n.t(.forwardGroups))
                        VStack(spacing: 0) {
                            ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { index, group in
                                targetButton(
                                    name: group.name,
                                    subtitle: "\(group.participantCount) \(l10n.t(.chatDetailGroupMembers))",
                                    colors: group.avatarColors,
                                    initials: nil,
                                    imageURL: nil,
                                    symbol: "person.3.fill",
                                    isOnline: false,
                                    isSelected: selectedGroupIDs.contains(group.id)
                                ) { toggleGroup(group.id) }
                                if index < filteredGroups.count - 1 { rowDivider }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .background(Theme.hairline(for: colorScheme))
            .padding(.leading, 76)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .tracking(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.forwardSearch), text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card(for: colorScheme))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func targetButton(name: String, subtitle: String, colors: [UInt], initials: String?, imageURL: String?, symbol: String?, isOnline: Bool, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Avatar(colors: colors, symbol: symbol, initials: initials, imageURL: imageURL, size: 48, isOnline: isOnline)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .lineLimit(1)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.coral : Theme.hairline(for: colorScheme), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle().fill(Theme.coral).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "paperplane")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.forwardNoTargets))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }

    // MARK: - Selection

    private func toggleFriend(_ id: UUID) {
        if selectedFriendIDs.contains(id) { selectedFriendIDs.remove(id) } else { _ = selectedFriendIDs.insert(id) }
    }

    private func toggleGroup(_ id: UUID) {
        if selectedGroupIDs.contains(id) { selectedGroupIDs.remove(id) } else { _ = selectedGroupIDs.insert(id) }
    }

    // MARK: - Forward

    /// Hands the source + selected targets to the edge function. The server reuses
    /// the existing send functions (re-validating friend/member), so a target I'm
    /// not allowed to write to is rejected there — never client-trusted.
    private func forward() {
        guard canSend else { return }
        let friendIds = Array(selectedFriendIDs)
        let groupIds = Array(selectedGroupIDs)
        isSending = true
        Task {
            do {
                try await data.forwardMessage(source: source, friendIds: friendIds, groupIds: groupIds)
                isSending = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                isSending = false
                showError = true
                print("⚠️ forward failed: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ForwardMessageView(source: ForwardSource(kind: .dm, messageIds: [UUID()]))
            .environment(LocalizationManager())
            .environment(AppDataService(userId: nil))
    }
}
