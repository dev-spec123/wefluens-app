//
//  ContactDetailView.swift
//  WeConnect
//

import SwiftUI

struct ContactDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    let contact: Contact
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirm: Bool = false
    @State private var isRemoving: Bool = false
    @State private var showRemoveError: Bool = false
    @State private var openingChat: Bool = false
    @State private var chatRoute: DMChatRoute?
    @State private var showChatError: Bool = false
    // Trust & Safety
    @State private var reportTarget: ReportTarget?
    @State private var showBlockConfirm: Bool = false
    @State private var isBlocking: Bool = false
    @State private var showBlockError: Bool = false
    // Friend remark (备注) — local-only custom name I see for this friend.
    @State private var showRemarkEditor: Bool = false
    @State private var remarkDraft: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                stats
                actions
                remarkCard
                infoCard
                removeButton
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(
            l10n.t(.contactDetailRemoveFriendMsg),
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.contactDetailRemoveFriend), role: .destructive) { removeFriend() }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .alert(l10n.t(.contactDetailRemoveFriendError), isPresented: $showRemoveError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .alert(l10n.t(.chatStartError), isPresented: $showChatError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .navigationDestination(item: $chatRoute) { route in
            ChatDetailView(route: route)
        }
        .confirmationDialog(
            l10n.t(.blockConfirm),
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.blockAction), role: .destructive) { block() }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .alert(l10n.t(.blockError), isPresented: $showBlockError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target)
        }
        .sheet(isPresented: $showRemarkEditor) {
            remarkEditor
        }
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
        .overlay(alignment: .topTrailing) {
            Menu {
                Button {
                    reportTarget = ReportTarget(user: contact.id, name: contact.name)
                } label: {
                    Label(l10n.t(.reportTitle), systemImage: "flag")
                }
                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label(l10n.t(.blockAction), systemImage: "hand.raised")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(.trailing, 18)
            .padding(.top, 8)
        }
    }

    /// Blocks this contact (records the block, drops the friendship, hides them
    /// everywhere) and pops back to the previous screen.
    private func block() {
        guard !isBlocking else { return }
        isBlocking = true
        Task {
            do {
                try await data.blockUser(contact.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isBlocking = false
                dismiss()
            } catch {
                isBlocking = false
                showBlockError = true
                print("⚠️ block failed: \(error)")
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, size: 96, isOnline: contact.isOnline)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            VStack(spacing: 4) {
                Text(data.remark(for: contact.id) ?? contact.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                // When a remark (备注) is set, show the real name beneath it so the
                // friend's actual identity stays visible.
                if let remark = data.remark(for: contact.id), !remark.isEmpty {
                    Text("\(l10n.t(.contactsRemark)) · \(contact.name)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
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
        Button {
            startChat()
        } label: {
            HStack(spacing: 8) {
                if openingChat {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "bubble.left.fill")
                }
                Text(l10n.t(.contactDetailMessage))
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.sunset)
            .clipShape(Capsule())
            .shadow(color: Theme.coral.opacity(0.35), radius: 12, y: 6)
        }
        .disabled(openingChat)
    }

    /// Opens (or creates) the 1:1 thread with this friend via get_or_create_thread,
    /// then pushes the real chat screen. Pure DB — never sends any email.
    private func startChat() {
        guard !openingChat else { return }
        openingChat = true
        Task {
            do {
                let threadId = try await data.getOrCreateThread(with: contact.id)
                chatRoute = DMChatRoute(
                    threadId: threadId,
                    otherUserId: contact.id,
                    title: contact.name,
                    avatarColors: contact.avatarColors,
                    initials: contact.initials,
                    isOnline: contact.isOnline,
                    avatarURL: contact.avatarUrl
                )
            } catch {
                print("⚠️ get_or_create_thread failed: \(error)")
                showChatError = true
            }
            openingChat = false
        }
    }

    /// Loads the current remark into the draft and presents the styled editor.
    private func openRemarkEditor() {
        remarkDraft = data.remark(for: contact.id) ?? ""
        showRemarkEditor = true
    }

    /// Always-visible "Set remark" (备注) card on the profile — mirrors the RN
    /// row with a pricetag icon, the current value inline, and a chevron.
    private var remarkCard: some View {
        Button {
            openRemarkEditor()
        } label: {
            let remark = data.remark(for: contact.id) ?? ""
            HStack(spacing: 14) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 38, height: 38)
                    .background(Theme.coral.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t(.contactsRemark))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    Text(remark.isEmpty ? l10n.t(.contactsRemarkPlaceholder) : remark)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(remark.isEmpty ? Theme.inkTertiary(for: colorScheme) : Theme.ink(for: colorScheme))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    /// Styled remark editor presented as a sheet — TextField with a ~40-char
    /// limit and Cancel/Save, mirroring the RN modal.
    private var remarkEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(l10n.t(.contactsSetRemark))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink(for: colorScheme))

            TextField(l10n.t(.contactsRemarkPlaceholder), text: $remarkDraft)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .submitLabel(.done)
                .onSubmit { saveRemark() }
                .onChange(of: remarkDraft) { _, newValue in
                    if newValue.count > 40 {
                        remarkDraft = String(newValue.prefix(40))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.cardSubtle(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
                )

            HStack(spacing: 10) {
                Button {
                    showRemarkEditor = false
                } label: {
                    Text(l10n.t(.adminCancel))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.cardSubtle(for: colorScheme))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    saveRemark()
                } label: {
                    Text(l10n.t(.editProfileSave))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.coral)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .background(Theme.paper(for: colorScheme))
    }

    /// Trims and persists the remark, then dismisses the editor.
    private func saveRemark() {
        data.setRemark(remarkDraft.trimmingCharacters(in: .whitespacesAndNewlines), for: contact.id)
        showRemarkEditor = false
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

    private var removeButton: some View {
        Button {
            showRemoveConfirm = true
        } label: {
            HStack(spacing: 8) {
                if isRemoving {
                    ProgressView().tint(Theme.danger)
                } else {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(l10n.t(.contactDetailRemoveFriend))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.danger.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isRemoving)
        .padding(.top, 4)
    }

    /// Calls remove_friend (two-sided, atomic), then pops back. The contact list
    /// and count refresh automatically because they derive from `friendships`.
    private func removeFriend() {
        guard !isRemoving else { return }
        isRemoving = true
        Task {
            do {
                try await data.removeFriend(friendId: contact.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isRemoving = false
                dismiss()
            } catch {
                isRemoving = false
                showRemoveError = true
                print("⚠️ remove_friend failed: \(error)")
            }
        }
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
