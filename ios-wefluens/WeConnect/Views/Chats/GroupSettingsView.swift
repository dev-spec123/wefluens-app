//
//  GroupSettingsView.swift
//  WeConnect
//
//  Group info screen: the member roster (visible to any member), owner-only
//  rename + remove, and member-invite (any member may add their own friends).
//
//  Every write goes through a SECURITY DEFINER function that re-checks the rule
//  server-side (group_rename / group_remove_member = owner-only; group_add_member
//  = any member, friends-only; the owner can never be removed), so the UI gating
//  here is convenience only — the backend is the source of truth and can't be
//  bypassed by a tampered client. This view never touches the chat bubbles.
//

import SwiftUI

struct GroupSettingsView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let groupId: UUID
    let initialName: String
    /// Called after any change (rename / add / remove) with the latest name +
    /// member count, so the chat header and inbox reflect it without a manual refresh.
    var onChanged: ((String, Int) -> Void)? = nil

    @State private var members: [GroupMember] = []
    @State private var currentName: String = ""
    @State private var nameDraft: String = ""
    @State private var isLoading: Bool = true
    @State private var isSavingName: Bool = false
    @State private var showAddMembers: Bool = false
    @State private var memberToRemove: GroupMember?
    @State private var errorMessage: String?

    /// I'm the owner when my own member row carries the owner flag (server-stamped).
    private var isOwner: Bool {
        guard let uid = data.userId else { return false }
        return members.first(where: { $0.id == uid })?.isOwner ?? false
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveName: Bool {
        isOwner && !trimmedName.isEmpty && trimmedName != currentName && !isSavingName
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if isLoading && members.isEmpty {
                Spacer()
                ProgressView().tint(Theme.coral)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        nameSection
                        membersSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert(errorMessage ?? "", isPresented: errorBinding) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { errorMessage = nil }
        }
        .confirmationDialog(
            l10n.t(.groupSettingsRemoveConfirm),
            isPresented: removeConfirmBinding,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.groupSettingsRemove), role: .destructive) {
                if let target = memberToRemove { remove(target) }
            }
            Button(l10n.t(.adminCancel), role: .cancel) { memberToRemove = nil }
        }
        .sheet(isPresented: $showAddMembers) {
            NavigationStack {
                GroupAddMembersView(
                    groupId: groupId,
                    existingMemberIDs: Set(members.map { $0.id }),
                    onAdded: { Task { await reload() } }
                )
            }
        }
        .task {
            if currentName.isEmpty {
                currentName = initialName
                nameDraft = initialName
            }
            await reload()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var removeConfirmBinding: Binding<Bool> {
        Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } })
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

            Text(l10n.t(.groupSettingsTitle))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink(for: colorScheme))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Name

    /// The group's name. Owner sees an editable field with an inline Save button
    /// that only enables on a real change; everyone else sees it read-only.
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(l10n.t(.groupSettingsName))

            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.sunset)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                if isOwner {
                    TextField(l10n.t(.groupSettingsNamePlaceholder), text: $nameDraft)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .submitLabel(.done)
                        .onSubmit { if canSaveName { saveName() } }
                } else {
                    Text(currentName.isEmpty ? l10n.t(.groupSettingsNamePlaceholder) : currentName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if isOwner {
                    saveNameButton
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var saveNameButton: some View {
        if isSavingName {
            ProgressView().tint(Theme.coral)
        } else {
            Button(action: saveName) {
                Text(l10n.t(.groupSettingsSave))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSaveName ? .white : Theme.inkTertiary(for: colorScheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(canSaveName ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.cardSubtle(for: colorScheme)))
                    .clipShape(Capsule())
            }
            .disabled(!canSaveName)
            .animation(.easeInOut(duration: 0.2), value: canSaveName)
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("\(l10n.t(.groupSettingsMembers)) · \(members.count)")
                Spacer()
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showAddMembers = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(l10n.t(.groupSettingsAddMembers))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.coral)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    memberRow(member)
                    if index < members.count - 1 {
                        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 68)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Theme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    private func memberRow(_ member: GroupMember) -> some View {
        HStack(spacing: 12) {
            Avatar(colors: member.avatarColors, initials: member.initials, imageURL: member.avatarUrl, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                if !member.handle.isEmpty {
                    Text("@\(member.handle)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if member.isOwner {
                Text(l10n.t(.groupSettingsOwner))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.coral.opacity(colorScheme == .dark ? 0.18 : 0.1))
                    .clipShape(Capsule())
            } else if isOwner {
                // Owner-only: remove any non-owner member (the owner row never shows this).
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    memberToRemove = member
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .tracking(1)
    }

    // MARK: - Actions

    private func reload() async {
        do {
            let roster = try await data.listGroupMembers(groupId: groupId)
            members = roster
            isLoading = false
            onChanged?(currentName, roster.count)
        } catch {
            isLoading = false
            print("⚠️ list_group_members failed: \(error)")
        }
    }

    /// Owner-only rename. The server re-checks ownership; on success we mirror the
    /// new name locally and bubble it up so the chat header + inbox update.
    private func saveName() {
        guard canSaveName else { return }
        let newName = trimmedName
        isSavingName = true
        Task {
            do {
                try await data.renameGroup(groupId: groupId, name: newName)
                currentName = newName
                isSavingName = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onChanged?(newName, members.count)
            } catch {
                isSavingName = false
                errorMessage = l10n.t(.groupSettingsRenameError)
                print("⚠️ group_rename failed: \(error)")
            }
        }
    }

    /// Owner-only remove (the owner can never be removed — gated here and on the server).
    private func remove(_ member: GroupMember) {
        memberToRemove = nil
        Task {
            do {
                try await data.removeGroupMember(groupId: groupId, userId: member.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await reload()
            } catch {
                errorMessage = l10n.t(.groupSettingsRemoveError)
                print("⚠️ group_remove_member failed: \(error)")
            }
        }
    }
}

// MARK: - Add Members (friend picker)

/// Multi-select picker to invite friends into the group. Lists my friends minus
/// those already in the group; each pick is added via `group_add_member` (any
/// member may invite, but only their own friend — re-validated server-side).
private struct GroupAddMembersView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let groupId: UUID
    let existingMemberIDs: Set<UUID>
    var onAdded: (() -> Void)? = nil

    @State private var searchText: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var isAdding: Bool = false
    @State private var showError: Bool = false

    /// Friends who aren't already in the group.
    private var candidates: [Contact] {
        data.contacts.filter { !existingMemberIDs.contains($0.id) }
    }

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return candidates }
        return candidates.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.handle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var canAdd: Bool { !selectedIDs.isEmpty && !isAdding }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            content
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert(l10n.t(.groupSettingsAddError), isPresented: $showError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .task {
            if data.contacts.isEmpty { await data.loadContacts() }
        }
    }

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
                Text(l10n.t(.groupSettingsAddMembers))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                if !selectedIDs.isEmpty {
                    Text("\(selectedIDs.count) \(l10n.t(.createGroupSelected))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
            }

            Spacer()

            if isAdding {
                ProgressView().tint(Theme.coral).frame(width: 44, height: 32)
            } else {
                Button(action: add) {
                    Text(l10n.t(.groupSettingsSave))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canAdd ? Theme.coral : Theme.inkTertiary(for: colorScheme))
                }
                .disabled(!canAdd)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if candidates.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    searchField
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, contact in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toggle(contact.id) }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            row(for: contact)
                        }
                        .buttonStyle(.plain)
                        if index < filtered.count - 1 {
                            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 76)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
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
        .padding(.bottom, 6)
    }

    private func row(for contact: Contact) -> some View {
        let isSelected = selectedIDs.contains(contact.id)
        return HStack(spacing: 14) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, size: 48, isOnline: contact.isOnline)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                if !contact.handle.isEmpty {
                    Text("@\(contact.handle)")
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
            Text(l10n.t(.groupSettingsNoFriendsToAdd))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { _ = selectedIDs.insert(id) }
    }

    /// Adds every selected friend via `group_add_member` (member + friends-only,
    /// re-validated server-side). Surfaces a real error on any failure.
    private func add() {
        guard canAdd else { return }
        let ids = Array(selectedIDs)
        isAdding = true
        Task {
            var failed = false
            for id in ids {
                do {
                    try await data.addGroupMember(groupId: groupId, userId: id)
                } catch {
                    failed = true
                    print("⚠️ group_add_member failed for \(id): \(error)")
                }
            }
            isAdding = false
            if failed {
                showError = true
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onAdded?()
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupSettingsView(groupId: UUID(), initialName: "Summer Campaign")
            .environment(LocalizationManager())
            .environment(AppDataService(userId: nil))
    }
}
