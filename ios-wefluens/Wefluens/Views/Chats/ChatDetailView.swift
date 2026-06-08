//
//  ChatDetailView.swift
//  Wefluens
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
    @FocusState private var inputFocused: Bool

    private var messages: [ChatMessage] { vm?.messages ?? [] }

    /// The newest message I sent — the only one that shows a read receipt
    /// (iMessage-style: a single lightweight status line, not one per bubble).
    private var lastMineId: UUID? {
        messages.last(where: { $0.sender == .me })?.id
    }

    /// Messages paired with their resolved quoted message (if any), so each row can
    /// render the quote preview without an O(n²) lookup. Built once per body eval.
    private var renderedMessages: [RenderedMessage] {
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
        .task {
            guard vm == nil else { return }
            let model = ChatThreadViewModel(route: route, data: data)
            vm = model
            await model.start()
        }
        .onDisappear {
            let model = vm
            Task { await model?.stop() }
        }
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

            Button {
            } label: {
                Image(systemName: "phone.fill")
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
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
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
    var onTapQuoted: ((UUID) -> Void)? = nil

    private var isMe: Bool { message.sender == .me }

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
                        if message.kind == .text {
                            Button {
                                UIPasteboard.general.string = message.text
                            } label: {
                                Label(l10n.t(.chatCopy), systemImage: "doc.on.doc")
                            }
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
            if let quotedSender, let quotedPreview {
                QuotedReplyPreview(senderName: quotedSender, preview: quotedPreview, isMe: isMe)
                    .contentShape(Rectangle())
                    .onTapGesture { if let quotedId { onTapQuoted?(quotedId) } }
            }

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
/// vertical accent bar, the original sender's name, and a single-line preview.
/// Tinted for my-bubble (on coral) vs theirs, and for light/dark.
private struct QuotedReplyPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let senderName: String
    let preview: String
    var isMe: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isMe ? Color.white.opacity(0.9) : Theme.coral)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(senderName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isMe ? Color.white.opacity(0.95) : Theme.coral)
                    .lineLimit(1)
                Text(preview)
                    .font(.system(size: 13))
                    .foregroundStyle(isMe ? Color.white.opacity(0.85) : Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            isMe ? Color.white.opacity(0.18) : Theme.inkSecondary(for: colorScheme).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Image Message Bubble

/// Renders an image message. Loads a short-lived signed URL for the private
/// `chat-media` object, reserves space using the stored pixel dimensions to avoid
/// layout jump, and clips to the same 20pt rounded rectangle as text bubbles.
/// An optional caption appears beneath in a matching bubble.
private struct ChatImageBubble: View {
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
private struct ChatFileBubble: View {
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
