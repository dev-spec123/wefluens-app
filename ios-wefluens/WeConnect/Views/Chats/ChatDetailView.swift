//
//  ChatDetailView.swift
//  WeConnect
//
//  Real 1:1 chat: loads messages from Supabase, sends via send_dm, and updates
//  live via Realtime. Beautiful rounded WeChat-style bubbles preserved.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct ChatDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let route: DMChatRoute

    @State private var vm: ChatThreadViewModel?
    @State private var draft: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var fileError: String?
    /// Briefly set when the user taps a quote, to flash the original message.
    @State private var highlightedId: UUID?
    /// Set by long-press → Forward; drives the target-picker sheet (nil = closed).
    @State private var forwardSource: ForwardSource?
    /// Confirmation dialog for clearing the chat history.
    @State private var showClearConfirm: Bool = false
    @FocusState private var inputFocused: Bool

    private var messages: [ChatMessage] { vm?.messages ?? [] }

    /// The newest message I sent — the only one that shows a read receipt
    /// (iMessage-style: a single lightweight status line, not one per bubble).
    private var lastMineId: UUID? {
        messages.last(where: { $0.sender == .me })?.id
    }

    /// Messages paired with their resolved quoted message (if any), so each row can
    /// render the quote preview without an O(n²) lookup. Cached in @State and rebuilt
    /// only when `messages` actually changes (see `.onChange` below) instead of on
    /// every body evaluation — the old computed property rebuilt the whole dictionary
    /// each frame, which stutters once a thread has many messages.
    @State private var renderedMessages: [RenderedMessage] = []

    /// Pure, static rebuild of the quote-resolved rows (never captures `self`).
    private static func buildRenderedMessages(from messages: [ChatMessage]) -> [RenderedMessage] {
        let byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return messages.map { RenderedMessage(message: $0, quoted: $0.replyTo.flatMap { byId[$0] }) }
    }

    /// A message + its resolved quoted original, identified by the message id.
    private struct RenderedMessage: Identifiable {
        let message: ChatMessage
        let quoted: ChatMessage?
        var id: UUID { message.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            messageList
            if let replying = vm?.replyingTo {
                replyComposerBar(for: replying)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputBar
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
        .task {
            guard vm == nil else { return }
            let model = ChatThreadViewModel(route: route, data: data)
            vm = model
            await model.start()
        }
        .onChange(of: messages, initial: true) { _, newMessages in
            renderedMessages = Self.buildRenderedMessages(from: newMessages)
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

    /// Common document types the file importer accepts (PDF / Word / Excel /
    /// PowerPoint / text). Photos and videos use their own pickers.
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

            Avatar(colors: route.avatarColors, initials: route.initials, imageURL: route.avatarURL, size: 40, isOnline: route.isOnline)

            VStack(alignment: .leading, spacing: 1) {
                Text(route.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(route.isOnline ? l10n.t(.chatDetailActiveNow) : l10n.t(.chatDetailOffline))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(route.isOnline ? Color(hex: 0x2AD17E) : Theme.inkSecondary(for: colorScheme))
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
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(Theme.paper(for: colorScheme))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(renderedMessages) { item in
                            MessageBubble(
                                message: item.message,
                                showReadReceipt: item.message.id == lastMineId,
                                quotedSender: item.quoted.map { quotedSenderName(for: $0) },
                                quotedPreview: item.quoted.map { quotedPreviewText(for: $0) },
                                quotedId: item.quoted?.id,
                                isHighlighted: item.message.id == highlightedId,
                                onReply: { startReply(to: item.message) },
                                onForward: { forwardSource = ForwardSource(kind: .dm, messageId: item.message.id) },
                                onDelete: { Task { await vm?.deleteMessage(item.message.id) } },
                                onRecall: { Task { await vm?.recallMessage(item.message.id) } },
                                onTapQuoted: { id in scrollToMessage(id, proxy: proxy) }
                            )
                            .id(item.message.id)
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

    private var canSend: Bool {
        vm != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends through send_dm (real DB write). Clears the field immediately for a
    /// snappy feel; the message list re-reads from the server.
    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let vm else { return }
        draft = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await vm.send(text) }
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

    // MARK: - Quoted replies

    /// Display name for a quoted message's original sender ("You" for mine).
    private func quotedSenderName(for message: ChatMessage) -> String {
        message.sender == .me ? l10n.t(.chatYou) : route.title
    }

    /// Single-line preview for a quoted message, by kind (mirrors the list preview).
    private func quotedPreviewText(for message: ChatMessage) -> String {
        switch message.kind {
        case .text:
            return message.text
        case .image:
            return l10n.t(.chatImagePreview)
        case .video:
            return l10n.t(.chatVideoPreview)
        case .file:
            let name = message.fileName ?? ""
            return name.isEmpty ? l10n.t(.chatFilePreview) : name
        }
    }

    /// Begins a quoted reply: shows the composer bar and focuses the input.
    private func startReply(to message: ChatMessage) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            vm?.replyingTo = message
        }
        inputFocused = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Scrolls to a quoted message and briefly highlights it (tap on a quote block).
    private func scrollToMessage(_ id: UUID, proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            proxy.scrollTo(id, anchor: .center)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        highlightedId = id
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            if highlightedId == id {
                withAnimation(.easeOut(duration: 0.45)) { highlightedId = nil }
            }
        }
    }

    /// The "replying to" context bar shown above the input while composing a quoted
    /// reply. The × clears it; sending also clears it (in the view model).
    private func replyComposerBar(for message: ChatMessage) -> some View {
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
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(LocalizationManager.self) private var l10n
    let message: ChatMessage
    /// True only for my most recent message — gates the read receipt below it.
    var showReadReceipt: Bool = false
    /// Resolved quoted message's sender label + single-line preview (nil = no quote).
    var quotedSender: String? = nil
    var quotedPreview: String? = nil
    var quotedId: UUID? = nil
    /// Briefly true when the user taps a quote pointing at this message.
    var isHighlighted: Bool = false
    var onReply: (() -> Void)? = nil
    var onForward: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRecall: (() -> Void)? = nil
    var onTapQuoted: ((UUID) -> Void)? = nil

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
        HStack(alignment: .bottom, spacing: 6) {
            if isMe {
                Spacer(minLength: 50)
                timestampView
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                bubbleColumn
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isHighlighted ? Theme.coral.opacity(0.16) : Color.clear)
                            .padding(-6)
                    )
                    .contextMenu {
                        Button { onReply?() } label: {
                            Label(l10n.t(.chatReply), systemImage: "arrowshape.turn.up.left")
                        }
                        Button { onForward?() } label: {
                            Label(l10n.t(.chatForward), systemImage: "arrowshape.turn.up.right")
                        }
                        if message.kind == .text {
                            Button {
                                UIPasteboard.general.string = message.text
                            } label: {
                                Label(l10n.t(.chatCopy), systemImage: "doc.on.doc")
                            }
                        }
                        Divider()
                        if message.sender == .me && isWithinRecallWindow {
                            Button(role: .destructive) { onRecall?() } label: {
                                Label(l10n.t(.chatRecall), systemImage: "arrow.uturn.backward")
                            }
                        }
                        Button(role: .destructive) { onDelete?() } label: {
                            Label(l10n.t(.chatDelete), systemImage: "trash")
                        }
                    }

                if isMe && showReadReceipt {
                    readReceipt
                }
            }

            if !isMe {
                timestampView
                Spacer(minLength: 50)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isHighlighted)
    }

    /// The quoted-reply preview (when present) stacked above the original message
    /// bubble. The kind branches below are byte-for-byte the originals — the
    /// `textBubble` / `ChatImageBubble` / `ChatFileBubble` views are never modified.
    @ViewBuilder
    private var bubbleColumn: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
            if message.isRecalled {
                recalledPlaceholder
            } else if let quotedSender, let quotedPreview {
                QuotedReplyPreview(senderName: quotedSender, preview: quotedPreview, isMe: isMe)
                    .contentShape(Rectangle())
                    .onTapGesture { if let quotedId { onTapQuoted?(quotedId) } }
            }

            if !message.isRecalled {
                if message.kind == .image, let path = message.imagePath {
                    ChatImageBubble(
                        path: path,
                        pixelWidth: message.imageWidth,
                        pixelHeight: message.imageHeight,
                        caption: message.text,
                        isMe: isMe
                    )
                } else if message.kind == .file, let path = message.imagePath {
                    ChatFileBubble(
                        path: path,
                        fileName: message.fileName ?? "",
                        fileSize: message.fileSize,
                        isMe: isMe
                    )
                } else {
                    textBubble
                }
            }
        }
    }

    /// Gray placeholder shown when a message has been recalled — replaces the
    /// original bubble entirely. Never touches textBubble / ChatImageBubble / ChatFileBubble.
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

    /// Uniform pill / rounded-rectangle bubble (no tail), identical shape for both
    /// sides. Width follows the content, so short messages stay small and long ones
    /// wrap — it can never self-intersect into a circle the way the old tail shape did.
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
                    colorScheme == .dark
                        ? Theme.card(for: .dark)
                        : Color(hex: 0xF0EBE4)
                }
            })
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: isMe
                        ? Theme.coral.opacity(0.25)
                        : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                    radius: isMe ? 6 : 3,
                    y: isMe ? 3 : 1)
    }

    /// Lightweight iMessage-style status under my last sent message: "Read" once
    /// the recipient has opened it (live via the realtime UPDATE), otherwise
    /// "Delivered". Subtle gray, with a soft cross-fade when it flips.
    private var readReceipt: some View {
        Text(message.readAt != nil ? l10n.t(.chatRead) : l10n.t(.chatDelivered))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .contentTransition(.opacity)
            .padding(.trailing, 4)
            .padding(.top, 1)
            .animation(.easeInOut(duration: 0.25), value: message.readAt)
    }

    private var timestampView: some View {
        Text(message.time)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .padding(.bottom, 6)
    }
}

// MARK: - Quoted Reply Preview

/// A compact quote shown above a message bubble when it replies to another: a
/// brand-gradient accent bar, the original sender's name, and a single-line
/// preview on a subtle translucent panel. Text is opaque dark/light (never a
/// faded gray or semi-transparent white) so it stays WCAG-AA legible; my-side
/// gets a warm tint, theirs a neutral scrim.
private struct QuotedReplyPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let senderName: String
    let preview: String
    var isMe: Bool = false

    /// Translucent panel behind the quote so it reads as a distinct layer.
    /// Warm tint for my messages (ties to the coral bubble), neutral scrim for theirs.
    private var panelFill: Color {
        if isMe {
            return colorScheme == .dark ? Theme.tangerine.opacity(0.24) : Theme.tangerine.opacity(0.16)
        }
        return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    /// Quoted content — the most prominent line. Dark gray on light, near-white on dark.
    private var bodyColor: Color {
        colorScheme == .dark ? Color(hex: 0xEDEDED) : Color(hex: 0x3A3A3A)
    }

    /// Sender name — readable and semibold, a touch lighter than the body.
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

// MARK: - Image Message Bubble

/// Renders an image message. Loads a short-lived signed URL for the private
/// `chat-media` object, reserves space using the stored pixel dimensions to avoid
/// layout jump, and clips to the same 20pt rounded rectangle as text bubbles.
/// An optional caption appears beneath in a matching bubble.
/// Internal (not private) so the group chat reuses the exact same image bubble.
struct ChatImageBubble: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    let path: String
    let pixelWidth: Int?
    let pixelHeight: Int?
    let caption: String
    let isMe: Bool

    @State private var url: URL?
    @State private var didFail = false

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// Display size capped to a chat-friendly box, preserving aspect ratio.
    private var displaySize: CGSize {
        let maxW: CGFloat = 232
        let maxH: CGFloat = 300
        let w = CGFloat(max(pixelWidth ?? 0, 0))
        let h = CGFloat(max(pixelHeight ?? 0, 0))
        guard w > 0, h > 0 else { return CGSize(width: maxW, height: maxW * 0.7) }
        let ratio = h / w
        var dw = maxW
        var dh = dw * ratio
        if dh > maxH {
            dh = maxH
            dw = dh / ratio
        }
        return CGSize(width: dw, height: dh)
    }

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
            imageBox
            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 15.5))
                    .foregroundStyle(isMe ? .white : Theme.ink(for: colorScheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe
                                ? AnyShapeStyle(Theme.sunset)
                                : AnyShapeStyle(colorScheme == .dark ? Theme.card(for: .dark) : Color(hex: 0xF0EBE4)))
                    .clipShape(shape)
            }
        }
    }

    // Color anchor sets the layout size; the image fills it inside an overlay and
    // is clipped — the standard pattern that keeps `.fill` from breaking layout.
    private var imageBox: some View {
        Theme.cardSubtle(for: colorScheme)
            .frame(width: displaySize.width, height: displaySize.height)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderIcon
                        case .empty:
                            ProgressView().tint(Theme.coral)
                        @unknown default:
                            ProgressView().tint(Theme.coral)
                        }
                    }
                } else if didFail {
                    placeholderIcon
                } else {
                    ProgressView().tint(Theme.coral)
                }
            }
            .clipShape(shape)
            .overlay(shape.stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            .shadow(color: isMe ? Theme.coral.opacity(0.18) : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.05),
                    radius: 5, y: 2)
            .task(id: path) {
                didFail = false
                do {
                    url = try await data.signedChatImageURL(path: path)
                } catch {
                    didFail = true
                    print("⚠️ signed chat image url failed: \(error)")
                }
            }
    }

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 28))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
    }
}

// MARK: - File Message Bubble

/// Renders a file attachment as a compact chip (icon + name + size) in the same
/// 20pt rounded-rectangle style as the other bubbles. Tapping downloads the
/// private `chat-media` object via a signed URL and opens it in QuickLook.
/// Internal (not private) so the group chat reuses the exact same file bubble.
struct ChatFileBubble: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let path: String
    let fileName: String
    let fileSize: Int?
    let isMe: Bool

    @State private var previewURL: URL?
    @State private var preparedURL: URL?
    @State private var isLoading = false

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    private var displayName: String {
        fileName.isEmpty ? l10n.t(.chatAttachFile) : fileName
    }

    private var sizeText: String {
        guard let fileSize, fileSize > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    private var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    private var iconName: String {
        switch fileExtension {
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx", "pages": return "doc.text.fill"
        case "xls", "xlsx", "csv", "numbers": return "tablecells.fill"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle.fill"
        case "zip", "rar", "7z": return "doc.zipper"
        case "txt", "rtf": return "doc.plaintext.fill"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch fileExtension {
        case "pdf": return Color(hex: 0xFF5A5F)
        case "doc", "docx", "pages": return Color(hex: 0x2B7CD3)
        case "xls", "xlsx", "csv", "numbers": return Color(hex: 0x1FA463)
        case "ppt", "pptx", "key": return Color(hex: 0xE8703A)
        case "zip", "rar", "7z": return Color(hex: 0x9B7BD4)
        default: return Color(hex: 0x8A8A8E)
        }
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.white)
                    if isLoading {
                        ProgressView().tint(iconColor)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 22))
                            .foregroundStyle(iconColor)
                    }
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isMe ? .white : Theme.ink(for: colorScheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !sizeText.isEmpty {
                        Text(sizeText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isMe ? .white.opacity(0.85) : Theme.inkSecondary(for: colorScheme))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 244, alignment: .leading)
            .background(isMe
                        ? AnyShapeStyle(Theme.sunset)
                        : AnyShapeStyle(colorScheme == .dark ? Theme.card(for: .dark) : Color(hex: 0xF0EBE4)))
            .clipShape(shape)
            .shadow(color: isMe ? Theme.coral.opacity(0.25) : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                    radius: isMe ? 6 : 3, y: isMe ? 3 : 1)
        }
        .buttonStyle(.plain)
        .quickLookPreview($previewURL)
    }

    /// Downloads the file once (cached as `preparedURL`) and presents QuickLook.
    private func open() {
        if let preparedURL {
            previewURL = preparedURL
            return
        }
        guard !isLoading else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let signed = try await data.signedChatImageURL(path: path)
                let (tmp, _) = try await URLSession.shared.download(from: signed)
                let dir = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(displayName)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                preparedURL = dest
                previewURL = dest
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                print("⚠️ file preview download failed: \(error)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(route: DMChatRoute(
            threadId: UUID(),
            otherUserId: UUID(),
            title: "Maya Rivera",
            avatarColors: [0x7B2FF7, 0xF107A3],
            initials: "MR",
            isOnline: true,
            avatarURL: nil
        ))
        .environment(LocalizationManager())
        .environment(AppDataService(userId: nil))
    }
}
