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
    /// Confirmation dialog for clearing the group chat history.
    @State private var showClearConfirm: Bool = false
    /// Opens the group info / settings sheet.
    @State private var showSettings: Bool = false
    /// Live header overrides applied after a rename / member change in settings,
    /// so the title + member count update without leaving the chat.
    @State private var liveTitle: String?
    @State private var liveMemberCount: Int?
    @FocusState private var inputFocused: Bool

    private var messages: [GroupChatMessage] { vm?.messages ?? [] }

    private var rows: [GroupRow] {
        var result: [GroupRow] = []
        for (i, m) in messages.enumerated() {
            let prev = i > 0 ? messages[i - 1] : nil
            let startsRun = prev?.senderId != m.senderId
            result.append(GroupRow(
                message: m,
                startsRun: startsRun,
                showSenderHeader: m.sender == .them && startsRun
            ))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            messageList
            inputBar
        }
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

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 3) {
                        ForEach(rows) { row in
                            GroupMessageBubble(
                                message: row.message,
                                showSenderHeader: row.showSenderHeader,
                                onForward: { forwardSource = ForwardSource(kind: .group, messageId: row.message.id) },
                                onDelete: { Task { await vm?.deleteMessage(row.message.id) } },
                                onRecall: { Task { await vm?.recallMessage(row.message.id) } }
                            )
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: allowedDocTypes, allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let loaded = try? await item.loadTransferable(type: Data.self)
                photoItem = nil
                if let loaded { await vm?.sendImage(loaded) }
            }
        }
    }

    /// The "+" opens a menu to attach a photo or a document (a spinner replaces it
    /// while uploading). System-keyboard emoji already type straight into the field.
    @ViewBuilder
    private var plusButton: some View {
        if vm?.isSendingImage == true || vm?.isSendingFile == true {
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
}

// MARK: - Group Message Bubble

/// A group message row. Mine sits on the right (coral gradient); others sit on
/// the left with the sender's avatar + name (shown once per run). Reuses the 1:1
/// bubble look without touching the existing private bubble views.
private struct GroupMessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LocalizationManager.self) private var l10n
    let message: GroupChatMessage
    let showSenderHeader: Bool
    var onForward: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRecall: (() -> Void)? = nil

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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMe {
                Spacer(minLength: 50)
                timestamp
                content
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
                        content
                        timestamp
                    }
                }
                Spacer(minLength: 40)
            }
        }
        .contextMenu {
            Button { onForward?() } label: {
                Label(l10n.t(.chatForward), systemImage: "arrowshape.turn.up.right")
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
        }
    }

    /// Avatar on the first incoming message of a run; reserved (clear) space on
    /// the rest so consecutive bubbles stay aligned.
    @ViewBuilder
    private var avatarColumn: some View {
        if showSenderHeader {
            Avatar(
                colors: message.senderColors,
                initials: AppDataService.initials(from: message.senderName),
                imageURL: message.senderAvatarUrl,
                size: 34
            )
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
            case .text, .video:
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
        Text(message.text)
            .font(.system(size: 15.5))
            .foregroundStyle(isMe ? .white : Theme.ink(for: colorScheme))
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
