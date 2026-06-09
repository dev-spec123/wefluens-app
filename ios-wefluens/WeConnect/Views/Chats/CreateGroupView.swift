//
//  CreateGroupView.swift
//  WeConnect
//
//  Pick real friends (from the friendship graph) to start a group chat.
//  Creation is atomic via the friend-validated `create_group` RPC; on success
//  we jump straight into the new group's chat.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// Called with the freshly created group's route so the parent can dismiss
    /// this sheet and navigate straight into the new chat.
    var onCreated: ((GroupChatRoute) -> Void)? = nil

    @State private var searchText: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var groupName: String = ""
    @State private var isCreating: Bool = false
    @State private var showError: Bool = false

    /// Real friends derive from the friendship graph (same source as Contacts).
    private var friends: [Contact] { data.contacts }

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.handle.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Selected friends in stable (alphabetical) order for the chips + auto-name.
    private var selectedContacts: [Contact] {
        friends.filter { selectedIDs.contains($0.id) }
    }

    private var canCreate: Bool { selectedIDs.count >= 2 && !isCreating }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if !selectedContacts.isEmpty { selectedBar }
            content
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert(l10n.t(.createGroupError), isPresented: $showError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .task {
            if data.contacts.isEmpty { await data.loadContacts() }
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
                Text(l10n.t(.createGroupTitle))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            Spacer()

            createButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        if selectedIDs.isEmpty {
            return l10n.t(.createGroupSelect)
        }
        return "\(selectedIDs.count) \(l10n.t(.createGroupSelected))"
    }

    @ViewBuilder
    private var createButton: some View {
        if isCreating {
            ProgressView()
                .tint(Theme.coral)
                .frame(width: 44, height: 32)
        } else {
            Button(action: create) {
                Text(l10n.t(.createGroupCreate))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canCreate ? Theme.coral : Theme.inkTertiary(for: colorScheme))
            }
            .disabled(!canCreate)
        }
    }

    // MARK: - Selected chips

    private var selectedBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(selectedContacts) { contact in
                    selectedChip(contact)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.coral.opacity(colorScheme == .dark ? 0.12 : 0.06))
    }

    private func selectedChip(_ contact: Contact) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                _ = selectedIDs.remove(contact.id)
            }
        } label: {
            HStack(spacing: 6) {
                Avatar(colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, size: 28)
                Text(contact.name)
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
        if friends.isEmpty {
            if data.isLoadingContacts {
                Spacer()
                ProgressView().tint(Theme.coral)
                Spacer()
            } else {
                emptyState
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    groupNameField
                    searchField
                    contactList
                }
            }
        }
    }

    private var groupNameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.sunset)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            TextField(l10n.t(.createGroupNamePlaceholder), text: $groupName)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .submitLabel(.done)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.createGroupSearch), text: $searchText)
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
        .padding(.vertical, 12)
    }

    private var contactList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, contact in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        toggleSelection(contact.id)
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    row(for: contact)
                }
                .buttonStyle(.plain)

                if index < filtered.count - 1 {
                    Divider()
                        .background(Theme.hairline(for: colorScheme))
                        .padding(.leading, 76)
                }
            }
        }
        .padding(.bottom, 24)
    }

    /// Adds or removes a friend from the selection (Void return so it can sit
    /// inside `withAnimation` — `Set.remove`/`insert` return different types).
    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            _ = selectedIDs.insert(id)
        }
    }

    private func row(for contact: Contact) -> some View {
        let isSelected = selectedIDs.contains(contact.id)
        return HStack(spacing: 14) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, size: 48, isOnline: contact.isOnline)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                if !contact.role.isEmpty {
                    Text(contact.role)
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

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.createGroupNoFriends))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Text(l10n.t(.createGroupNoFriendsHint))
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }

    // MARK: - Create

    /// Builds the final group name (selected friends' names joined when the field
    /// is blank), then creates the group atomically and hands the route up so the
    /// parent can open the new chat.
    private func create() {
        guard canCreate else { return }
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = selectedContacts
        let memberIds = chosen.map { $0.id }
        let finalName: String
        if trimmed.isEmpty {
            let names = chosen.map { $0.name }
            let joined = names.prefix(4).joined(separator: ", ")
            finalName = names.count > 4 ? joined + "…" : joined
        } else {
            finalName = trimmed
        }

        isCreating = true
        Task {
            do {
                let groupId = try await data.createGroup(name: finalName, memberIds: memberIds)
                isCreating = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let route = GroupChatRoute(
                    groupId: groupId,
                    title: finalName,
                    avatarColors: AppDataService.avatarPalette(for: groupId),
                    memberCount: memberIds.count + 1,
                    avatarURL: nil
                )
                onCreated?(route)
            } catch {
                isCreating = false
                showError = true
                print("⚠️ create group failed: \(error)")
            }
        }
    }
}

#Preview {
    CreateGroupView()
        .environment(LocalizationManager())
        .environment(AppDataService(userId: nil))
}
