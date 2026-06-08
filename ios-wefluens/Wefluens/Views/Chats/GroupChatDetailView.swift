//
//  GroupChatDetailView.swift
//  Wefluens
//
//  Real group chat (text-only): loads messages from Supabase, sends via
//  send_group_message, and updates live via Realtime. Incoming bubbles show the
//  sender's avatar + name; consecutive messages from the same person are grouped.
//  Reuses the 1:1 bubble look without touching textBubble / ChatImageBubble /
//  ChatFileBubble.
//

import SwiftUI

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

    private var sendErrorBinding: Binding<Bool> {
        Binding(
            get: { vm?.sendFailed ?? false },
            set: { newValue in vm?.sendFailed = newValue }
        )
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
                Text(route.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text("\(route.memberCount) \(l10n.t(.chatDetailGroupMembers))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 40, height: 40)
                .background(Theme.card(for: colorScheme))
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
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
                                showSenderHeader: row.showSenderHeader
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
    let message: GroupChatMessage
    let showSenderHeader: Bool

    private var isMe: Bool { message.sender == .me }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isMe {
                Spacer(minLength: 50)
                timestamp
                bubble
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
                        bubble
                        timestamp
                    }
                }
                Spacer(minLength: 40)
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

    /// Uniform rounded-rectangle bubble — coral gradient for me, paper card for
    /// others (matches the 1:1 text bubble look exactly).
    private var bubble: some View {
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
