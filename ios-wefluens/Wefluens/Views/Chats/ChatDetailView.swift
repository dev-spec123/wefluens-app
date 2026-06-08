//
//  ChatDetailView.swift
//  Wefluens
//
//  Real 1:1 chat: loads messages from Supabase, sends via send_dm, and updates
//  live via Realtime. Beautiful rounded WeChat-style bubbles preserved.
//

import SwiftUI
import PhotosUI

struct ChatDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let route: DMChatRoute

    @State private var vm: ChatThreadViewModel?
    @State private var draft: String = ""
    @State private var photoItem: PhotosPickerItem?

    private var messages: [ChatMessage] { vm?.messages ?? [] }

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
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
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
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let loaded = try? await item.loadTransferable(type: Data.self)
                photoItem = nil
                if let loaded { await vm?.sendImage(loaded) }
            }
        }
    }

    /// The "+" opens the photo library (a spinner replaces it while sending).
    /// System-keyboard emoji already type straight into the text field.
    @ViewBuilder
    private var plusButton: some View {
        if vm?.isSendingImage == true {
            ProgressView()
                .tint(Theme.coral)
                .frame(width: 30, height: 30)
        } else {
            PhotosPicker(selection: $photoItem, matching: .images) {
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
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: ChatMessage

    private var isMe: Bool { message.sender == .me }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMe {
                Spacer(minLength: 50)
                timestampView
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if message.kind == .image, let path = message.imagePath {
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
            }

            if !isMe {
                timestampView
                Spacer(minLength: 50)
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

    private var timestampView: some View {
        Text(message.time)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .padding(.bottom, 6)
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
