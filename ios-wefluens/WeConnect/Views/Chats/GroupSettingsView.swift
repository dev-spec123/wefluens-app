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
import PhotosUI

struct GroupSettingsView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let groupId: UUID
    let initialName: String
    /// The group's current photo (if any). Owner can replace it via PhotosPicker.
    let initialAvatarUrl: String?
    /// Called after any change (rename / add / remove) with the latest name +
    /// member count, so the chat header and inbox reflect it without a manual refresh.
    var onChanged: ((String, Int) -> Void)? = nil
    /// Called after I leave or the owner dissolves the group, so the parent can pop
    /// back to the inbox (the group no longer exists for me).
    var onLeft: (() -> Void)? = nil

    init(
        groupId: UUID,
        initialName: String,
        initialAvatarUrl: String? = nil,
        onChanged: ((String, Int) -> Void)? = nil,
        onLeft: (() -> Void)? = nil
    ) {
        self.groupId = groupId
        self.initialName = initialName
        self.initialAvatarUrl = initialAvatarUrl
        self.onChanged = onChanged
        self.onLeft = onLeft
    }

    @State private var members: [GroupMember] = []
    @State private var currentName: String = ""
    @State private var nameDraft: String = ""
    @State private var isLoading: Bool = true
    @State private var isSavingName: Bool = false
    @State private var showAddMembers: Bool = false
    @State private var memberToRemove: GroupMember?
    @State private var selectedMember: GroupMember?
    @State private var errorMessage: String?

    // --- avatar ---
    @State private var avatarUrl: String?
    @State private var avatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar: Bool = false

    // --- mute (local, per-group UserDefaults flag) ---
    @State private var isMuted: Bool = false

    // --- leave / dissolve ---
    @State private var showLeaveConfirm: Bool = false
    @State private var showDissolveConfirm: Bool = false
    @State private var isLeaving: Bool = false

    /// UserDefaults key for this group's mute flag.
    private var muteKey: String { "wefluens.group.mute.\(groupId.uuidString)" }

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
                        muteSection
                        leaveDissolveSection
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
        .sheet(item: $selectedMember) { member in
            GroupMemberCard(member: member)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            l10n.t(.groupSettingsLeaveConfirm),
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.groupSettingsLeave), role: .destructive) { leave() }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .confirmationDialog(
            l10n.t(.groupSettingsDissolveConfirm),
            isPresented: $showDissolveConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.groupSettingsDissolve), role: .destructive) { dissolve() }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .onChange(of: avatarItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let imgData = try? await newItem.loadTransferable(type: Data.self) {
                    await changeAvatar(imgData)
                }
            }
        }
        .task {
            if currentName.isEmpty {
                currentName = initialName
                nameDraft = initialName
            }
            if avatarUrl == nil { avatarUrl = initialAvatarUrl }
            isMuted = UserDefaults.standard.bool(forKey: muteKey)
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
                groupAvatar

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

    /// The group photo. For the owner it's a PhotosPicker (tap to change); for
    /// other members it's a plain thumbnail. Falls back to the gradient + symbol
    /// placeholder when there's no photo yet.
    @ViewBuilder
    private var groupAvatar: some View {
        if isOwner {
            PhotosPicker(selection: $avatarItem, matching: .images) {
                avatarThumb
            }
            .buttonStyle(.plain)
        } else {
            avatarThumb
        }
    }

    private var avatarThumb: some View {
        ZStack(alignment: .bottomTrailing) {
            Avatar(
                colors: AppDataService.avatarPalette(for: groupId),
                symbol: "person.3.fill",
                imageURL: avatarUrl,
                size: 44
            )
            if isUploadingAvatar {
                ZStack {
                    Circle().fill(Color.black.opacity(0.35))
                    ProgressView().tint(.white).scaleEffect(0.7)
                }
                .frame(width: 44, height: 44)
            } else if isOwner {
                Image(systemName: "camera.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Theme.sunset)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.card(for: colorScheme), lineWidth: 2))
                    .offset(x: 3, y: 3)
            }
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
            // Tapping the avatar/name opens the member's info card.
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                selectedMember = member
            } label: {
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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    // MARK: - Mute

    /// "Mute Notifications" toggle. Local-only — persisted per group id in
    /// UserDefaults (no server round-trip), mirroring the Expo client's behavior.
    private var muteSection: some View {
        HStack(spacing: 12) {
            Image(systemName: isMuted ? "bell.slash.fill" : "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 22, height: 22)

            Text(l10n.t(.groupSettingsMute))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink(for: colorScheme))

            Spacer(minLength: 6)

            Toggle("", isOn: $isMuted)
                .labelsHidden()
                .tint(Theme.coral)
                .onChange(of: isMuted) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: muteKey)
                    UISelectionFeedbackGenerator().selectionChanged()
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
    }

    // MARK: - Leave / Dissolve

    /// "Leave Group" (every member) and, for the owner, "Dissolve Group". Both
    /// confirm first; the server re-checks the rule (membership DELETE = self-only;
    /// group_threads DELETE = owner-only).
    private var leaveDissolveSection: some View {
        VStack(spacing: 12) {
            Button { showLeaveConfirm = true } label: {
                dangerRow(icon: "rectangle.portrait.and.arrow.right", title: l10n.t(.groupSettingsLeave))
            }
            .buttonStyle(.plain)
            .disabled(isLeaving)

            if isOwner {
                Button { showDissolveConfirm = true } label: {
                    dangerRow(icon: "trash.fill", title: l10n.t(.groupSettingsDissolve))
                }
                .buttonStyle(.plain)
                .disabled(isLeaving)
            }
        }
    }

    private func dangerRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            if isLeaving {
                ProgressView().tint(Theme.danger).frame(width: 22, height: 22)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 22, height: 22)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.danger)
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        .contentShape(Rectangle())
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

    /// Owner-only avatar change. Uploads to the `avatars` bucket and stamps the URL
    /// onto group_threads (re-checked server-side). Mirrors the new photo locally.
    @MainActor
    private func changeAvatar(_ imageData: Data) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            let url = try await data.changeGroupAvatar(groupId: groupId, imageData: imageData)
            avatarUrl = url
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = l10n.t(.groupSettingsRenameError)
            print("⚠️ changeGroupAvatar failed: \(error)")
        }
    }

    /// Leaves the group (any member). On success notify the parent so it pops back.
    private func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        Task {
            do {
                try await data.leaveGroup(groupId: groupId)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isLeaving = false
                onLeft?()
                dismiss()
            } catch {
                isLeaving = false
                errorMessage = l10n.t(.groupSettingsRemoveError)
                print("⚠️ leaveGroup failed: \(error)")
            }
        }
    }

    /// Owner-only dissolve. On success notify the parent so it pops back.
    private func dissolve() {
        guard !isLeaving else { return }
        isLeaving = true
        Task {
            do {
                try await data.dissolveGroup(groupId: groupId)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isLeaving = false
                onLeft?()
                dismiss()
            } catch {
                isLeaving = false
                errorMessage = l10n.t(.groupSettingsRemoveError)
                print("⚠️ dissolveGroup failed: \(error)")
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

// MARK: - Member info card

/// Tapping a member in the roster opens this card: their avatar, name, @handle,
/// role + owner badge, and a context-aware action (Add Friend / Requested /
/// Friends / This is you).
private struct GroupMemberCard: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let member: GroupMember

    @State private var relationship: String = "none"
    @State private var busy = false
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 16) {
            Avatar(colors: member.avatarColors, initials: member.initials, imageURL: member.avatarUrl, size: 88)
                .padding(.top, 28)

            VStack(spacing: 6) {
                Text(member.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .multilineTextAlignment(.center)
                if !member.handle.isEmpty {
                    Text("@\(member.handle)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
            }

            HStack(spacing: 8) {
                if member.isOwner {
                    label(l10n.t(.groupSettingsOwner), icon: "crown.fill")
                }
                if !member.role.isEmpty {
                    TagChip(text: member.role, filled: false)
                }
            }

            actionButton
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Theme.ink(for: colorScheme).opacity(0.92))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { relationship = computeRelationship() }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch relationship {
        case "self":
            label(l10n.t(.groupMemberYou), icon: "person.fill")
        case "friends":
            label(l10n.t(.addFriendFriends), icon: "checkmark")
        case "request_sent":
            label(l10n.t(.addFriendRequested), icon: "clock")
        default:
            Button { addFriend() } label: {
                HStack(spacing: 6) {
                    if busy { ProgressView().tint(.white) }
                    else { Image(systemName: "person.badge.plus").font(.system(size: 14, weight: .bold)) }
                    Text(l10n.t(.addFriendAdd)).font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 26).padding(.vertical, 13)
                .background(Theme.sunset).clipShape(Capsule())
                .shadow(color: Theme.coral.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
            Text(text).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        .padding(.horizontal, 18).frame(height: 40)
        .background(Theme.cardSubtle(for: colorScheme)).clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
    }

    private func computeRelationship() -> String {
        if member.id == data.userId { return "self" }
        if data.contacts.contains(where: { $0.id == member.id }) { return "friends" }
        return "none"
    }

    private func addFriend() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let status = try await data.sendFriendRequest(to: member.id, message: l10n.t(.friendRequestMessage))
                switch status {
                case "sent":
                    relationship = "request_sent"
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    show(l10n.t(.addFriendSent))
                case "already_sent": relationship = "request_sent"
                case "already_friends": relationship = "friends"
                default: break
                }
                await data.loadContacts()
            } catch {
                show(l10n.t(.addFriendError))
            }
        }
    }

    private func show(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
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
