//
//  ChatsListView.swift
//  WeConnect
//

import SwiftUI

struct ChatsListView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @State private var showSearch: Bool = false
    @State private var showCreateGroup: Bool = false
    @State private var showAddFriend: Bool = false
    @State private var showFeedback: Bool = false
    @State private var showScan: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var conversationToDelete: Conversation?
    @State private var path = NavigationPath()

    private var conversations: [Conversation] { data.conversations }

    /// Pinned conversations float to the top of the list. `filtered` is already in
    /// recency order, so filtering preserves a stable order within the pinned group.
    private var pinned: [Conversation] {
        filtered.filter { data.isPinned($0.id) }
    }

    private var recent: [Conversation] {
        filtered.filter { !data.isPinned($0.id) }
    }

    /// Single continuous stream with pinned items floated to the top (no section
    /// headers) — matches the RN app's flat list feel.
    private var ordered: [Conversation] { pinned + recent }

    private var filtered: [Conversation] {
        guard !searchText.isEmpty else { return conversations }
        return conversations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.lastMessage.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unread }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    weListeningBanner
                    if showSearch { searchBar }

                    if ordered.isEmpty {
                        emptyState
                    } else {
                        conversationList(items: ordered)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await data.loadConversations() }
            .navigationDestination(for: DMChatRoute.self) { route in
                ChatDetailView(route: route)
            }
            .navigationDestination(for: GroupChatRoute.self) { route in
                GroupChatDetailView(route: route)
            }
            .fullScreenCover(isPresented: $showCreateGroup) {
                NavigationStack {
                    CreateGroupView(onCreated: { newRoute in
                        showCreateGroup = false
                        path.append(newRoute)
                    })
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showFeedback) {
                SupportContactView()
            }
            .fullScreenCover(isPresented: $showScan) {
                NavigationStack {
                    QRScanView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(l10n.t(.adminCancel)) { showScan = false }
                            }
                        }
                }
            }
            .alert(l10n.t(.convDelete), isPresented: $showDeleteConfirm) {
                Button(l10n.t(.convDelete), role: .destructive) {
                    if let convo = conversationToDelete {
                        Task { await deleteConversation(convo) }
                    }
                }
                Button(l10n.t(.adminCancel), role: .cancel) { }
            } message: {
                Text(l10n.t(.chatDeleteConversationWarn))
            }
            .onAppear {
                Task { await data.loadConversations() }
            }
        }
    }

    /// Clears the conversation history (unrecoverable, as warned) then hides it
    /// from the inbox — mirrors the RN delete flow. Best-effort: failures are
    /// swallowed so a transient error never leaves the row in a half-deleted state.
    private func deleteConversation(_ convo: Conversation) async {
        do {
            if convo.isGroup {
                try await data.clearGroupHistory(groupId: convo.id)
            } else {
                try await data.clearDMHistory(threadId: convo.id)
            }
            try await data.hideConversation(conversationId: convo.id, type: convo.isGroup ? "group" : "dm")
        } catch {
            // best effort
        }
    }

    /// Builds the navigation route for a real DM thread.
    private func route(for convo: Conversation) -> DMChatRoute {
        DMChatRoute(
            threadId: convo.id,
            otherUserId: convo.otherUserId ?? convo.id,
            title: convo.name,
            avatarColors: convo.avatarColors,
            initials: convo.avatarInitials ?? "?",
            isOnline: convo.isOnline,
            avatarURL: convo.avatarUrl
        )
    }

    /// Builds the navigation route for a group thread.
    private func groupRoute(for convo: Conversation) -> GroupChatRoute {
        GroupChatRoute(
            groupId: convo.id,
            title: convo.name,
            avatarColors: convo.avatarColors,
            memberCount: convo.participantCount,
            avatarURL: convo.avatarUrl
        )
    }

    /// Long-press context menu for a conversation row: pin/unpin (置顶), mute/unmute
    /// (免打扰), and delete (hides the conversation via the existing RPC).
    @ViewBuilder
    private func conversationMenu(for convo: Conversation) -> some View {
        let pinned = data.isPinned(convo.id)
        let muted = data.isMuted(convo.id)

        // The conversation name renders as a title header above the actions,
        // matching the RN ActionSheet's `title={menuConv.name}`.
        Section(convo.name) {
            Button {
                data.setPinned(convo.id, on: !pinned)
            } label: {
                Label(l10n.t(pinned ? .convUnpin : .convPin),
                      systemImage: pinned ? "pin.slash.fill" : "pin.fill")
            }

            Button {
                data.setMuted(convo.id, on: !muted)
            } label: {
                Label(l10n.t(muted ? .convUnmute : .convMute),
                      systemImage: muted ? "bell.fill" : "bell.slash.fill")
            }

            Button(role: .destructive) {
                conversationToDelete = convo
                showDeleteConfirm = true
            } label: {
                Label(l10n.t(.convDelete), systemImage: "trash.fill")
            }
        }
    }

    /// "We're Listening" — a pinned feedback banner at the top of Chats. Opens the
    /// feedback form (SupportContactView). Kept here until the team asks to remove it.
    private var weListeningBanner: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            showFeedback = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.t(.weListeningTitle))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(l10n.t(.weListeningSub))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.sunset)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Theme.coral.opacity(0.3), radius: 14, y: 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.chatsTitle))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(totalUnread > 0 ? "\(totalUnread) \(l10n.t(.chatsUnread))" : l10n.t(.chatsCaughtUp))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                        if !showSearch { searchText = "" }
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .frame(width: 44, height: 44)
                        .background(Theme.card(for: colorScheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                }
                Menu {
                    Button {
                        showCreateGroup = true
                    } label: {
                        Label(l10n.t(.chatsNewGroup), systemImage: "person.3.fill")
                    }
                    Button {
                        showAddFriend = true
                    } label: {
                        Label(l10n.t(.chatsAddFriend), systemImage: "person.badge.plus")
                    }
                    Button {
                        showScan = true
                    } label: {
                        Label(l10n.t(.chatsScan), systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.sunset)
                        .clipShape(Circle())
                        .shadow(color: Theme.coral.opacity(0.4), radius: 10, y: 5)
                }
            }
        }
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.chatsSearch), text: $searchText)
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
        .padding(.vertical, 13)
        .background(Theme.card(for: colorScheme))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
    }

    /// One continuous card of conversation rows (no section title) — pinned items
    /// are already floated to the top by `ordered`.
    private func conversationList(items: [Conversation]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, convo in
                SwipeableRow(
                    conversation: convo,
                    onDelete: {
                        conversationToDelete = convo
                        showDeleteConfirm = true
                    },
                    content: {
                        Group {
                            if convo.isGroup {
                                NavigationLink(value: groupRoute(for: convo)) {
                                    ConversationRow(conversation: convo, isPinned: data.isPinned(convo.id), isMuted: data.isMuted(convo.id))
                                }
                            } else {
                                NavigationLink(value: route(for: convo)) {
                                    ConversationRow(conversation: convo, isPinned: data.isPinned(convo.id), isMuted: data.isMuted(convo.id))
                                }
                            }
                        }
                    }
                )
                .buttonStyle(.plain)
                .contextMenu { conversationMenu(for: convo) }
                if index < items.count - 1 {
                    Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 78)
                }
            }
        }
        .padding(.vertical, 6)
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.chatsEmpty))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .padding(.top, 60)
    }
}

private struct ConversationRow: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let conversation: Conversation
    /// Local pin/mute prefs (置顶 / 免打扰), passed in from the parent so the row
    /// stays a pure presentation view. Drive the pin + mute indicators.
    let isPinned: Bool
    let isMuted: Bool

    /// Prepends a localized "You: " when I sent the last message (WeChat-style).
    /// Media messages show a localized placeholder: files always "[File]", images
    /// "[Photo]" only when caption-less (otherwise the caption shows).
    /// Recalled messages show a "Message recalled" placeholder regardless of type.
    private var previewText: String {
        // Recalled last message → show placeholder, never the original text
        if conversation.lastMessageRecalled {
            return conversation.lastFromMe
                ? l10n.t(.chatYouPrefix) + l10n.t(.chatMessageRecalled)
                : l10n.t(.chatMessageRecalled)
        }
        let base: String
        switch conversation.lastMessageType {
        case "file":
            base = l10n.t(.chatFilePreview)
        case "audio":
            base = l10n.t(.chatVoice)
        case "video":
            base = l10n.t(.chatVideoPreview)
        case "image" where conversation.lastMessage.isEmpty:
            base = l10n.t(.chatImagePreview)
        default:
            base = conversation.lastMessage
        }
        guard !base.isEmpty else { return "" }
        return conversation.lastFromMe
            ? l10n.t(.chatYouPrefix) + base
            : base
    }

    var body: some View {
        HStack(spacing: 14) {
            if let initials = conversation.avatarInitials {
                Avatar(
                    colors: conversation.avatarColors,
                    initials: initials,
                    imageURL: conversation.avatarUrl,
                    size: 54,
                    isOnline: conversation.isOnline
                )
            } else {
                Avatar(
                    colors: conversation.avatarColors,
                    symbol: conversation.avatar,
                    size: 54,
                    isOnline: conversation.isOnline
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(conversation.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .lineLimit(1)
                    if conversation.isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.coral)
                    }
                    if conversation.isGroup {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    }
                    if isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    }
                    if conversation.mentioned {
                        Image(systemName: "at")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.coral)
                    }
                }
                Text(previewText)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 8) {
                Text(conversation.time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(conversation.unread > 0 && !isMuted ? Theme.coral : Theme.inkTertiary(for: colorScheme))
                if conversation.unread > 0 {
                    Text(conversation.unread > 99 ? "99+" : "\(conversation.unread)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(isMuted ? AnyShapeStyle(Theme.inkTertiary(for: colorScheme)) : AnyShapeStyle(Theme.sunset))
                        .clipShape(Circle())
                } else if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.coral)
                        .rotationEffect(.degrees(45))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Swipeable Row

/// A row that supports swipe-to-delete via a drag gesture. The delete button
/// reveals from the trailing edge with a spring animation. Tapping the delete
/// button fires `onDelete` which shows a confirmation dialog in the parent.
private struct SwipeableRow<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let conversation: Conversation
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private let deleteWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red delete background revealed when swiped
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    offset = 0
                }
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .opacity(offset < 0 ? 1 : 0)

            // Main content slides left to reveal delete
            content()
                .offset(x: offset + dragOffset)
                .simultaneousGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            let delta = value.translation.width
                            if delta < 0 {
                                state = max(delta, -deleteWidth)
                            } else if offset < 0 {
                                state = min(delta - offset, 0)
                            }
                        }
                        .onEnded { value in
                            let threshold: CGFloat = -40
                            let velocity = value.predictedEndTranslation.width
                            if velocity < threshold || value.translation.width < threshold {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    offset = -deleteWidth
                                }
                            } else {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    offset = 0
                                }
                            }
                        }
                )
                .onChange(of: conversation.id) { _, _ in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        offset = 0
                    }
                }
        }
        .clipped()
    }
}

#Preview {
    ChatsListView()
        .environment(LocalizationManager())
}
