//
//  GroupChatDetailView.swift
//  WeConnect
//
//  Real group chat (text-only): loads messages from Supabase, sends via
//  send_group_message, and updates live via Realtime. Incoming bubbles show the
//  sender's avatar + name; consecutive messages from the same person are grouped.
//  Reuses the 1:1 bubble look without touching textBubble / ChatImageBubble /
//  ChatFileBubble.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// A message paired with whether it begins a new run from its sender, so incoming
/// bubbles only show the avatar + name on the first message of a run.
private struct GroupRow: Identifiable {
    let message: GroupChatMessage
    let startsRun: Bool
    let showSenderHeader: Bool
    /// The resolved original this message quotes (nil = not a reply).
    let quoted: GroupChatMessage?
    var id: UUID { message.id }
}

struct GroupChatDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let route: GroupChatRoute

    @State private var vm: GroupChatViewModel?
    @State private var draft: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var fileError: String?
    /// Set by long-press → Forward; drives the target-picker sheet (nil = closed).
    @State private var forwardSource: ForwardSource?
    // Multi-select (enter via long-press → Select; batch forward / delete).
    @State private var selectMode = false
    @State private var selectedIds = Set<UUID>()
    /// Confirmation dialog for clearing the group chat history.
    @State private var showClearConfirm: Bool = false
    /// Opens the group info / settings sheet.
    @State private var showSettings: Bool = false
    /// Live header overrides applied after a rename / member change in settings,
    /// so the title + member count update without leaving the chat.
    @State private var liveTitle: String?
    @State private var liveMemberCount: Int?
    // Trust & Safety
    @State private var reportTarget: ReportTarget?
    @State private var showBlockConfirm: Bool = false
    @State private var pendingBlockId: UUID?
    @State private var showBlockError: Bool = false
    /// Set when tapping a member's avatar to view their profile.
    @State private var profileContact: Contact?
    // Voice messages
    @State private var recorder = VoiceRecorder()
    @State private var showMicPermissionAlert = false
    // @mentions
    /// Cached group roster, loaded the first time the "@" button is tapped.
    @State private var members: [GroupMember] = []
    /// Drives the member picker for inserting an @mention (false = closed).
    @State private var showMentionPicker = false
    @FocusState private var inputFocused: Bool

    private var messages: [GroupChatMessage] { vm?.messages ?? [] }

    private var rows: [GroupRow] {
        let byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [GroupRow] = []
        for (i, m) in messages.enumerated() {
            let prev = i > 0 ? messages[i - 1] : nil
            let startsRun = prev?.senderId != m.senderId
            result.append(GroupRow(
                message: m,
                startsRun: startsRun,
                showSenderHeader: m.sender == .them && startsRun,
                quoted: m.replyTo.flatMap { byId[$0] }
            ))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if selectMode { selectNavBar } else { navBar }
            if let pin = data.pinnedMessages.message(for: route.groupId), !selectMode {
                pinnedBanner(pin)
            }
            messageList
            if selectMode {
                selectActionBar
            } else {
                if let replying = vm?.replyingTo {
                    replyComposerBar(for: replying)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                inputBar
            }
        }
        .overlay {
            if recorder.isRecording { recordingOverlay }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: vm?.replyingTo?.id)
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .alert(l10n.t(.chatSendError), isPresented: sendErrorBinding) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .alert(fileError ?? "", isPresented: fileErrorBinding) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { fileError = nil }
        }
        .sheet(item: $forwardSource) { source in
            NavigationStack {
                ForwardMessageView(source: source)
            }
        }
        .confirmationDialog(l10n.t(.chatClearHistoryConfirm), isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button(l10n.t(.chatClearHistory), role: .destructive) {
                Task { await vm?.clearHistory() }
            }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .alert(l10n.t(.chatRecallFailed), isPresented: recallErrorBinding) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { vm?.recallError = nil }
        } message: {
            if let key = vm?.recallError { Text(l10n.t(key)) }
        }
        .confirmationDialog(l10n.t(.blockConfirm), isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button(l10n.t(.blockAction), role: .destructive) {
                if let id = pendingBlockId { block(id) }
            }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .alert(l10n.t(.blockError), isPresented: $showBlockError) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .alert(l10n.t(.chatVoicePermissionDenied), isPresented: $showMicPermissionAlert) {
            Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
        }
        .confirmationDialog(l10n.t(.groupSettingsMembers), isPresented: $showMentionPicker, titleVisibility: .visible) {
            ForEach(mentionableMembers) { member in
                Button(member.name) { insertMention(member) }
            }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target)
        }
        .sheet(item: $profileContact) { contact in
            NavigationStack { ContactDetailView(contact: contact) }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                GroupSettingsView(
                    groupId: route.groupId,
                    initialName: liveTitle ?? route.title,
                    onChanged: { name, count in
                        liveTitle = name
                        liveMemberCount = count
                    }
                )
            }
        }
        .task {
            guard vm == nil else { return }
            let model = GroupChatViewModel(route: route, data: data)
            vm = model
            await model.start()
        }
        .onDisappear {
            let model = vm
            Task { await model?.stop() }
        }
    }

    private var recallErrorBinding: Binding<Bool> {
        Binding(
            get: { vm?.recallError != nil },
            set: { newValue in if !newValue { vm?.recallError = nil } }
        )
    }

    private var sendErrorBinding: Binding<Bool> {
        Binding(
            get: { vm?.sendFailed ?? false },
            set: { newValue in vm?.sendFailed = newValue }
        )
    }

    private var fileErrorBinding: Binding<Bool> {
        Binding(
            get: { fileError != nil },
            set: { newValue in if !newValue { fileError = nil } }
        )
    }

    /// Common document types the file importer accepts (mirrors the 1:1 chat).
    private var allowedDocTypes: [UTType] {
        var types: [UTType] = [.pdf, .plainText, .rtf]
        let ids = [
            "public.spreadsheet", "public.presentation", "public.composite-content",
            "org.openxmlformats.wordprocessingml.document", "com.microsoft.word.doc",
            "org.openxmlformats.spreadsheetml.sheet", "com.microsoft.excel.xls",
            "org.openxmlformats.presentationml.presentation", "com.microsoft.powerpoint.ppt"
        ]
        types.append(contentsOf: ids.compactMap { UTType($0) })
        return types
    }

    // MARK: - Nav bar

    // MARK: - Multi-select

    private func enterSelect(_ id: UUID) {
        selectMode = true
        selectedIds = [id]
    }
    private func exitSelect() {
        selectMode = false
        selectedIds = []
    }
    private func toggleSelect(_ id: UUID) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }
    private func forwardSelected() {
        let ids = messages.filter { selectedIds.contains($0.id) && !$0.isRecalled }.map { $0.id }
        guard !ids.isEmpty else { return }
        forwardSource = ForwardSource(kind: .group, messageIds: ids)
        exitSelect()
    }
    private func deleteSelected() {
        let ids = Array(selectedIds)
        guard !ids.isEmpty else { return }
        Task {
            for id in ids { await vm?.deleteMessage(id) }
            exitSelect()
        }
    }

    private var selectNavBar: some View {
        HStack(spacing: 12) {
            Button { exitSelect() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }
            Text("\(l10n.t(.chatSelectedLabel)) \(selectedIds.count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Theme.paper(for: colorScheme))
    }

    private var selectActionBar: some View {
        HStack {
            Button { forwardSelected() } label: {
                VStack(spacing: 3) {
                    Image(systemName: "arrowshape.turn.up.right").font(.system(size: 22))
                    Text(l10n.t(.chatForward)).font(.system(size: 12))
                }
                .foregroundStyle(selectedIds.isEmpty ? Theme.inkTertiary(for: colorScheme) : Theme.ink(for: colorScheme))
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedIds.isEmpty)
            Button { deleteSelected() } label: {
                VStack(spacing: 3) {
                    Image(systemName: "trash").font(.system(size: 22))
                    Text(l10n.t(.chatDelete)).font(.system(size: 12))
                }
                .foregroundStyle(selectedIds.isEmpty ? Theme.inkTertiary(for: colorScheme) : Theme.coral)
                .frame(maxWidth: .infinity)
            }
            .disabled(selectedIds.isEmpty)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Theme.paper(for: colorScheme))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.hairline(for: colorScheme)), alignment: .top)
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }

            Avatar(colors: route.avatarColors, symbol: "person.3.fill", size: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(liveTitle ?? route.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text("\(liveMemberCount ?? route.memberCount) \(l10n.t(.chatDetailGroupMembers))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(l10n.t(.chatClearHistory), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettings = true
            } label: {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Theme.paper(for: colorScheme))
    }

    // MARK: - Pinned banner (群公告)

    /// A slim coral-tinted banner pinned to the top of the chat when the group has a
    /// pinned message: 📌 + the "Pinned" label + a single line of text, with an ✕ to
    /// unpin. Tapping ✕ removes the pin (local-only, on-device).
    private func pinnedBanner(_ pin: PinnedMessage) -> some View {
        HStack(spacing: 8) {
            Text("📌")
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 1) {
                Text(l10n.t(.pinnedLabel))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                Text(pin.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                data.pinnedMessages.unpin(in: route.groupId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.coral.opacity(0.10))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline(for: colorScheme))
                .frame(height: 1)
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 3) {
                        ForEach(rows) { row in
                            HStack(spacing: 8) {
                                if selectMode {
                                    Image(systemName: selectedIds.contains(row.message.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedIds.contains(row.message.id) ? Theme.coral : Theme.inkTertiary(for: colorScheme))
                                }
                                GroupMessageBubble(
                                    message: row.message,
                                    showSenderHeader: row.showSenderHeader,
                                    isPinned: data.pinnedMessages.isPinned(row.message.id, in: route.groupId),
                                    quotedSender: row.quoted.map { quotedSenderName(for: $0) },
                                    quotedPreview: row.quoted.map { quotedPreviewText(for: $0) },
                                    onReply: { startReply(to: row.message) },
                                    onForward: { forwardSource = ForwardSource(kind: .group, messageIds: [row.message.id]) },
                                    onSelect: { enterSelect(row.message.id) },
                                    onFavorite: { favorite(row.message) },
                                    onPin: { pin(row.message) },
                                    onUnpin: { data.pinnedMessages.unpin(in: route.groupId) },
                                    onDelete: { Task { await vm?.deleteMessage(row.message.id) } },
                                    onRecall: { Task { await vm?.recallMessage(row.message.id) } },
                                    onReport: {
                                        reportTarget = ReportTarget(
                                            messageId: row.message.id,
                                            kind: "group",
                                            excerpt: row.message.text,
                                            userId: row.message.senderId,
                                            name: row.message.senderName
                                        )
                                    },
                                    onBlock: {
                                        pendingBlockId = row.message.senderId
                                        showBlockConfirm = true
                                    },
                                    onTapAvatar: {
                                        openProfile(memberId: row.message.senderId,
                                                    name: row.message.senderName,
                                                    avatarUrl: row.message.senderAvatarUrl,
                                                    colors: row.message.senderColors)
                                    }
                                )
                                .allowsHitTesting(!selectMode)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { if selectMode { toggleSelect(row.message.id) } }
                            .id(row.message.id)
                            .padding(.top, row.startsRun ? 8 : 0)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 38))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.chatThreadEmpty))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Composer

    // MARK: - Quoted replies

    /// Display name for a quoted message's original sender ("You" for mine).
    private func quotedSenderName(for message: GroupChatMessage) -> String {
        message.sender == .me ? l10n.t(.chatYou) : message.senderName
    }

    /// Single-line preview for a quoted message, by kind (mirrors the list preview).
    private func quotedPreviewText(for message: GroupChatMessage) -> String {
        switch message.kind {
        case .text: return message.text
        case .image: return l10n.t(.chatImagePreview)
        case .video: return l10n.t(.chatVideoPreview)
        case .file:
            let name = message.fileName ?? ""
            return name.isEmpty ? l10n.t(.chatFilePreview) : name
        case .audio: return l10n.t(.chatVoice)
        }
    }

    private func startReply(to message: GroupChatMessage) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            vm?.replyingTo = message
        }
        inputFocused = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// "Replying to" context bar above the input while composing a quoted reply.
    private func replyComposerBar(for message: GroupChatMessage) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.coral)
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(quotedSenderName(for: message))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .lineLimit(1)
                Text(quotedPreviewText(for: message))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    vm?.cancelReply()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(Theme.card(for: colorScheme))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            plusButton

            HStack {
                TextField(l10n.t(.chatDetailMessagePlaceholder), text: $draft, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1...4)
                    .focused($inputFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Theme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))

            mentionButton

            micButton

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.inkTertiary(for: colorScheme)))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Theme.paper(for: colorScheme))
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .any(of: [.images, .videos]))
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: allowedDocTypes, allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            Task {
                let loaded = try? await item.loadTransferable(type: Data.self)
                photoItem = nil
                if let loaded {
                    if isVideo { await vm?.sendVideo(loaded) }
                    else { await vm?.sendImage(loaded) }
                }
            }
        }
    }

    /// The "+" opens a menu to attach a photo or a document (a spinner replaces it
    /// while uploading). System-keyboard emoji already type straight into the field.
    @ViewBuilder
    private var plusButton: some View {
        if vm?.isSendingImage == true || vm?.isSendingFile == true || vm?.isSendingVideo == true {
            ProgressView()
                .tint(Theme.coral)
                .frame(width: 30, height: 30)
        } else {
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(l10n.t(.chatAttachPhoto), systemImage: "photo")
                }
                Button {
                    showFileImporter = true
                } label: {
                    Label(l10n.t(.chatAttachFile), systemImage: "doc")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .frame(width: 30, height: 30)
            }
        }
    }

    /// The "@" button loads the group roster (cached after the first tap) and then
    /// presents a picker of members to mention. Tapping a member inserts
    /// `@Name ` into the draft.
    private var mentionButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            loadMembersAndPresentPicker()
        } label: {
            Image(systemName: "at")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 44, height: 44)
                .background(Theme.card(for: colorScheme))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    /// Members eligible to be @mentioned — everyone except me.
    private var mentionableMembers: [GroupMember] {
        members.filter { $0.id != data.userId }
    }

    /// Loads the roster (reusing the cache once populated) then opens the picker.
    private func loadMembersAndPresentPicker() {
        if !members.isEmpty {
            showMentionPicker = true
            return
        }
        Task {
            do {
                members = try await data.listGroupMembers(groupId: route.groupId)
            } catch {
                print("⚠️ load group members failed: \(error)")
            }
            if !mentionableMembers.isEmpty {
                showMentionPicker = true
            }
        }
    }

    /// Appends `@Name ` to the draft, adding a leading space when the draft is
    /// non-empty and doesn't already end in whitespace.
    private func insertMention(_ member: GroupMember) {
        if !draft.isEmpty, let last = draft.last, !last.isWhitespace {
            draft += " "
        }
        draft += "@\(member.name) "
        inputFocused = true
    }

    /// Reads the picked document into memory (enforcing the 25 MB cap with a real
    /// error — never silent), then sends it via the view model.
    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let vm else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let maxBytes = 25 * 1024 * 1024
                guard data.count <= maxBytes else {
                    fileError = l10n.t(.chatFileTooLarge)
                    return
                }
                let name = url.lastPathComponent
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await vm.sendFile(data: data, fileName: name, mimeType: mime) }
            } catch {
                fileError = l10n.t(.chatFileError)
                print("⚠️ file read failed: \(error)")
            }
        case .failure(let error):
            print("⚠️ file import cancelled/failed: \(error)")
        }
    }

    /// Press-and-hold microphone button. A long-press (min 0s) starts recording;
    /// releasing the finger ends it and sends. Shows a spinner while uploading.
    @ViewBuilder
    private var micButton: some View {
        if vm?.isSendingVoice == true {
            ProgressView()
                .tint(Theme.coral)
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(recorder.isRecording ? .white : Theme.coral)
                .frame(width: 44, height: 44)
                .background(recorder.isRecording
                            ? AnyShapeStyle(Theme.sunset)
                            : AnyShapeStyle(Theme.card(for: colorScheme)))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: recorder.isRecording ? 0 : 1))
                .scaleEffect(recorder.isRecording ? 1.12 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recorder.isRecording)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !recorder.isRecording { startRecording() }
                        }
                        .onEnded { _ in
                            stopRecordingAndSend()
                        }
                )
        }
    }

    /// A centered "recording…" indicator shown while the mic is held.
    private var recordingOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: true)
                Text(l10n.t(.chatRecording))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(String(format: "%d:%02d", Int(recorder.elapsed) / 60, Int(recorder.elapsed) % 60))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .background(Theme.coral.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.18).ignoresSafeArea())
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// Begins recording (requests mic permission as needed). Surfaces a permission
    /// alert if it was denied so the user can enable it in Settings.
    private func startRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            let started = await recorder.start()
            if !started && recorder.permissionDenied {
                recorder.permissionDenied = false
                showMicPermissionAlert = true
            }
        }
    }

    /// Stops recording and sends the clip (clips under ~0.5s are discarded).
    private func stopRecordingAndSend() {
        guard recorder.isRecording else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let data = recorder.stopAndFetchData()
        guard let data, let vm else { return }
        Task { await vm.sendVoice(data) }
    }

    private var canSend: Bool {
        vm != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends through send_group_message (real DB write). Clears the field
    /// immediately for a snappy feel; the message list re-reads from the server.
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let vm else { return }
        draft = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await vm.send(text) }
    }

    /// Saves a group message to local favorites (收藏). Uses a kind-aware preview so
    /// media reads as e.g. "[Photo]" rather than blank, and shows "You" for my own
    /// messages (otherwise the sender's name).
    /// Opens a group member's profile (reuses their Contact when we're friends,
    /// else builds a lightweight one from the message's sender info).
    private func openProfile(memberId: UUID, name: String, avatarUrl: String?, colors: [UInt]) {
        if let existing = data.contacts.first(where: { $0.id == memberId }) {
            profileContact = existing
        } else {
            profileContact = Contact(
                id: memberId,
                name: name,
                handle: "",
                role: "",
                platform: "",
                followers: "0",
                avatarColors: colors,
                isOnline: false,
                avatarUrl: avatarUrl
            )
        }
    }

    private func favorite(_ message: GroupChatMessage) {
        data.favorites.add(Favorite(
            id: message.id,
            text: favoritePreview(for: message),
            kind: kindLabel(for: message.kind),
            sender: message.sender == .me ? l10n.t(.chatYou) : message.senderName,
            source: "group",
            date: message.createdAt ?? Date()
        ))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Pins a group message as the group's 群公告 banner (local-only, on-device).
    /// Reuses the kind-aware single-line preview so media reads as e.g. "[Photo]"
    /// rather than blank, and records the pinner's name ("You" for my own messages).
    private func pin(_ message: GroupChatMessage) {
        data.pinnedMessages.pin(
            PinnedMessage(
                id: message.id,
                text: favoritePreview(for: message),
                by: message.sender == .me ? l10n.t(.chatYou) : message.senderName
            ),
            in: route.groupId
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Single-line preview for a favorited group message, by kind (mirrors the 1:1 chat).
    private func favoritePreview(for message: GroupChatMessage) -> String {
        switch message.kind {
        case .text:
            return message.text
        case .image:
            return l10n.t(.chatImagePreview)
        case .video:
            return message.text.isEmpty ? l10n.t(.chatVideoPreview) : message.text
        case .file:
            let name = message.fileName ?? ""
            return name.isEmpty ? l10n.t(.chatFilePreview) : name
        case .audio:
            return l10n.t(.chatVoice)
        }
    }

    /// Stable string label for a message kind, stored on the favorite.
    private func kindLabel(for kind: ChatMessageKind) -> String {
        switch kind {
        case .text: return "text"
        case .image: return "image"
        case .video: return "video"
        case .file: return "file"
        case .audio: return "audio"
        }
    }

    /// Blocks a group member: their messages are hidden from me everywhere and they
    /// leave my contacts. The group reloads so their bubbles disappear immediately.
    private func block(_ id: UUID) {
        Task {
            do {
                try await data.blockUser(id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await vm?.reload()
            } catch {
                showBlockError = true
                print("⚠️ block failed: \(error)")
            }
        }
    }
}

// MARK: - Group Message Bubble

/// A group message row. Mine sits on the right (coral gradient); others sit on
/// the left with the sender's avatar + name (shown once per run). Reuses the 1:1
/// bubble look without touching the existing private bubble views.
/// Quoted-original panel shown above a group reply bubble (mirrors the 1:1 one).
private struct GroupQuotedReplyPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let senderName: String
    let preview: String
    var isMe: Bool = false

    private var panelFill: Color {
        if isMe {
            return colorScheme == .dark ? Theme.tangerine.opacity(0.24) : Theme.tangerine.opacity(0.16)
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    private var bodyColor: Color {
        colorScheme == .dark ? Color(hex: 0xEDEDED) : Color(hex: 0x3A3A3A)
    }
    private var nameColor: Color {
        colorScheme == .dark ? Color(hex: 0xC0C0C0) : Color(hex: 0x595959)
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.sunset)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(senderName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundStyle(bodyColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct GroupMessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LocalizationManager.self) private var l10n
    let message: GroupChatMessage
    let showSenderHeader: Bool
    /// True when this message is the group's currently pinned (群公告) message — the
    /// menu then offers "Unpin" instead of "Pin".
    var isPinned: Bool = false
    var quotedSender: String? = nil
    var quotedPreview: String? = nil
    var onReply: (() -> Void)? = nil
    var onForward: (() -> Void)? = nil
    var onSelect: (() -> Void)? = nil
    var onFavorite: (() -> Void)? = nil
    var onPin: (() -> Void)? = nil
    var onUnpin: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRecall: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onBlock: (() -> Void)? = nil
    var onTapAvatar: (() -> Void)? = nil

    private var isMe: Bool { message.sender == .me }

    /// The recall window is 2 minutes from when the message was created.
    /// Client-side gate so the button is hidden for expired messages (server also
    /// enforces the hard 2-minute limit). Messages without a createdAt date
    /// (legacy / import) fall back to the old conservative behaviour: show
    /// the option and let the server decide.
    private var isWithinRecallWindow: Bool {
        guard isMe, !message.isRecalled else { return false }
        guard let createdAt = message.createdAt else { return true }
        return Date().timeIntervalSince(createdAt) <= 120
    }

    /// The bubble with its quoted-reply preview stacked above (when a reply).
    private var bubbleContent: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
            if let quotedSender, let quotedPreview {
                GroupQuotedReplyPreview(senderName: quotedSender, preview: quotedPreview, isMe: isMe)
            }
            content
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMe {
                Spacer(minLength: 50)
                timestamp
                bubbleContent
            } else {
                avatarColumn
                VStack(alignment: .leading, spacing: 3) {
                    if showSenderHeader {
                        Text(message.senderName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .padding(.leading, 2)
                    }
                    HStack(alignment: .bottom, spacing: 6) {
                        bubbleContent
                        timestamp
                    }
                }
                Spacer(minLength: 40)
            }
        }
        .contextMenu {
            Button { onReply?() } label: {
                Label(l10n.t(.chatReply), systemImage: "arrowshape.turn.up.left")
            }
            Button { onForward?() } label: {
                Label(l10n.t(.chatForward), systemImage: "arrowshape.turn.up.right")
            }
            Button { onSelect?() } label: {
                Label(l10n.t(.chatSelect), systemImage: "checkmark.circle")
            }
            if message.kind == .text {
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label(l10n.t(.chatCopy), systemImage: "doc.on.doc")
                }
            }
            if !message.isRecalled {
                Button { onFavorite?() } label: {
                    Label(l10n.t(.favoriteAction), systemImage: "star")
                }
                if isPinned {
                    Button { onUnpin?() } label: {
                        Label(l10n.t(.unpinMessage), systemImage: "pin.slash")
                    }
                } else {
                    Button { onPin?() } label: {
                        Label(l10n.t(.pinMessage), systemImage: "pin")
                    }
                }
            }
            if !isMe {
                Button { onReport?() } label: {
                    Label(l10n.t(.reportTitle), systemImage: "flag")
                }
            }
            Divider()
            if isWithinRecallWindow {
                Button(role: .destructive) { onRecall?() } label: {
                    Label(l10n.t(.chatRecall), systemImage: "arrow.uturn.backward")
                }
            }
            Button(role: .destructive) { onDelete?() } label: {
                Label(l10n.t(.chatDelete), systemImage: "trash")
            }
            if !isMe {
                Button(role: .destructive) { onBlock?() } label: {
                    Label(l10n.t(.blockAction), systemImage: "hand.raised")
                }
            }
        }
    }

    /// Avatar on the first incoming message of a run; reserved (clear) space on
    /// the rest so consecutive bubbles stay aligned.
    @ViewBuilder
    private var avatarColumn: some View {
        if showSenderHeader {
            Button { onTapAvatar?() } label: {
                Avatar(
                    colors: message.senderColors,
                    initials: AppDataService.initials(from: message.senderName),
                    imageURL: message.senderAvatarUrl,
                    size: 34
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 34, height: 1)
        }
    }

    /// Branches on the message kind, reusing the exact 1:1 image / file bubbles for
    /// media (caption / name / size handled inside them) and the group text bubble
    /// for text. Video falls back to its caption text for now.
    @ViewBuilder
    private var content: some View {
        if message.isRecalled {
            recalledPlaceholder
        } else {
            switch message.kind {
            case .image:
                if let path = message.imagePath {
                    ChatImageBubble(
                        path: path,
                        pixelWidth: message.imageWidth,
                        pixelHeight: message.imageHeight,
                        caption: message.text,
                        isMe: isMe
                    )
                } else {
                    textBubble
                }
            case .file:
                if let path = message.imagePath {
                    ChatFileBubble(
                        path: path,
                        fileName: message.fileName ?? "",
                        fileSize: message.fileSize,
                        isMe: isMe
                    )
                } else {
                    textBubble
                }
            case .audio:
                if let path = message.imagePath {
                    AudioMessageBubble(path: path, isMe: isMe)
                } else {
                    textBubble
                }
            case .video:
                if let path = message.imagePath {
                    ChatVideoBubble(path: path, caption: message.text, isMe: isMe)
                } else {
                    textBubble
                }
            case .text:
                textBubble
            }
        }
    }

    /// Gray placeholder shown when a message has been recalled.
    private var recalledPlaceholder: some View {
        Text(l10n.t(.chatMessageRecalled))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .italic()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.cardSubtle(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Uniform rounded-rectangle bubble — coral gradient for me, paper card for
    /// others (matches the 1:1 text bubble look exactly).
    private var textBubble: some View {
        Text(mentionAttributed(message.text, base: isMe ? .white : Theme.ink(for: colorScheme)))
            .font(.system(size: 15.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Group {
                if isMe {
                    Theme.sunset
                } else {
                    colorScheme == .dark ? Theme.card(for: .dark) : Color(hex: 0xF0EBE4)
                }
            })
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: isMe
                        ? Theme.coral.opacity(0.25)
                        : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                    radius: isMe ? 6 : 3,
                    y: isMe ? 3 : 1)
    }

    /// Builds an `AttributedString` from the message text where any `@token`
    /// (regex `@[^\s@]+`) is colored `Theme.coral` and semibold; the rest uses
    /// `base` (white on my coral bubble, ink on others').
    private func mentionAttributed(_ text: String, base: Color) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = base

        guard let regex = try? NSRegularExpression(pattern: "@[^\\s@]+") else { return result }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            guard let range = Range(match.range, in: text),
                  let attrRange = Range(range, in: result) else { continue }
            result[attrRange].foregroundColor = Theme.coral
            result[attrRange].font = .system(size: 15.5, weight: .semibold)
        }
        return result
    }

    private var timestamp: some View {
        Text(message.time)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .padding(.bottom, 6)
    }
}

#Preview {
    NavigationStack {
        GroupChatDetailView(route: GroupChatRoute(
            groupId: UUID(),
            title: "Summer Campaign",
            avatarColors: [0xFF6B35, 0xF7C948],
            memberCount: 4,
            avatarURL: nil
        ))
        .environment(LocalizationManager())
        .environment(AppDataService(userId: nil))
    }
}
