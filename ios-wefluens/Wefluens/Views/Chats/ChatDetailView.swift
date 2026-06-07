//
//  ChatDetailView.swift
//  Wefluens
//
//  Beautiful chat detail with rounded WeChat-style bubbles.
//

import SwiftUI

struct ChatDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let conversation: Conversation

    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage]
    @State private var draft: String = ""

    init(conversation: Conversation) {
        self.conversation = conversation
        _messages = State(initialValue: conversation.messages)
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

            Avatar(colors: conversation.avatarColors, symbol: conversation.avatar, size: 40, isOnline: conversation.isOnline)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(conversation.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                    if conversation.isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.coral)
                    }
                }
                if conversation.isGroup {
                    Text("\(conversation.participantCount) \(l10n.t(.chatDetailGroupMembers))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                } else {
                    Text(conversation.isOnline ? l10n.t(.chatDetailActiveNow) : l10n.t(.chatDetailOffline))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(conversation.isOnline ? Color(hex: 0x2AD17E) : Theme.inkSecondary(for: colorScheme))
                }
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
                LazyVStack(spacing: 8) {
                    Text(l10n.t(.chatDetailToday))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        .padding(.vertical, 6)

                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

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
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let new = ChatMessage(text: text, sender: .me, time: formatter.string(from: Date()))
        messages.append(new)
        draft = ""
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
                    .clipShape(BubbleShape(isMe: isMe))
                    .shadow(color: isMe
                                ? Theme.coral.opacity(0.25)
                                : Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
                            radius: isMe ? 6 : 3,
                            y: isMe ? 3 : 1)
            }

            if !isMe {
                timestampView
                Spacer(minLength: 50)
            }
        }
    }

    private var timestampView: some View {
        Text(message.time)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .padding(.bottom, 6)
    }
}

// MARK: - Bubble Shape

/// A beautiful, smooth bubble with a subtle tail — inspired by WeChat.
private struct BubbleShape: Shape {
    let isMe: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18       // main corner radius
        let tailW: CGFloat = 6
        let tailH: CGFloat = 8
        let tailX: CGFloat = isMe ? rect.maxX - 4 : 4
        let tailY: CGFloat = rect.maxY - 2

        var path = Path()

        // Start at top-left
        path.move(to: CGPoint(x: r, y: 0))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        // Top-right corner
        path.addArc(center: CGPoint(x: rect.maxX - r, y: r),
                    radius: r,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false)

        // Right edge (skip tail area)
        path.addLine(to: CGPoint(x: rect.maxX, y: tailY - tailH))

        // Tail on the right (my message) or left (their message)
        if isMe {
            // Tail pointing right
            path.addLine(to: CGPoint(x: tailX, y: tailY))
            path.addLine(to: CGPoint(x: rect.maxX - tailW, y: tailY))
        } else {
            // No tail on right side for left message
        }

        // Bottom-right corner
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                    radius: r,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)

        // Bottom edge (skip tail area for left messages)
        if !isMe {
            path.addLine(to: CGPoint(x: tailX + tailW, y: rect.maxY))
            // Tail pointing left
            path.addLine(to: CGPoint(x: tailX, y: tailY))
            path.addLine(to: CGPoint(x: tailX, y: rect.maxY - tailH))
        }

        path.addLine(to: CGPoint(x: r, y: rect.maxY))

        // Bottom-left corner
        path.addArc(center: CGPoint(x: r, y: rect.maxY - r),
                    radius: r,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)

        // Left edge
        path.addLine(to: CGPoint(x: 0, y: r))

        // Top-left corner
        path.addArc(center: CGPoint(x: r, y: r),
                    radius: r,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)

        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(conversation: SampleData.conversations[0])
            .environment(LocalizationManager())
    }
}
