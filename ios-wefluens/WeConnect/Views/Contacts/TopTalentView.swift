//
//  TopTalentView.swift
//  WeConnect
//
//  The "Top Talent" creator directory — pushed from the Contacts tab.
//
//  Empty search field → the opt-in directory via `browse_top_talent` (ranked by
//  followers; only users who turned on "Discoverable"). Typing a query → a live
//  search across all users via `search_users` (same as Add Friend), so you can
//  still find someone by handle/name even if they haven't opted into the directory.
//  Each row offers the same Add Friend / Pending / Friends actions as AddFriendView.
//

import SwiftUI

struct TopTalentView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme

    @State private var people: [SearchUserResult] = []        // the directory
    @State private var isLoading = true
    @State private var loadFailed = false

    @State private var searchText = ""
    @State private var searchResults: [SearchUserResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil

    /// Relationship overrides applied immediately after an action (optimistic UI).
    @State private var localRelationship: [UUID: String] = [:]
    @State private var actioning: Set<UUID> = []
    @State private var toast: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isSearchActive: Bool { trimmedQuery.count >= 2 }
    private var displayed: [SearchUserResult] { isSearchActive ? searchResults : people }

    var body: some View {
        ZStack {
            Theme.paper(for: colorScheme).ignoresSafeArea()

            if isLoading {
                ProgressView().tint(Theme.coral).scaleEffect(1.1)
            } else {
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                    content
                }
            }

            if let toast { toastView(toast) }
        }
        .navigationTitle(l10n.t(.contactsTopTalent))
        .navigationBarTitleDisplayMode(.inline)
        .task { if isLoading { await load() } }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.talentSearch), text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    searchTask?.cancel()
                    isSearching = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Theme.card(for: colorScheme))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        .onChange(of: searchText) { _, newValue in scheduleSearch(newValue) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isSearchActive && isSearching && searchResults.isEmpty {
            VStack(spacing: 14) {
                ProgressView().tint(Theme.coral).scaleEffect(1.1)
                Text(l10n.t(.addFriendSearching))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayed.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { index, user in
                        row(user)
                        if index < displayed.count - 1 {
                            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 76)
                        }
                    }
                }
                .padding(.vertical, 6)
                .cardStyle()
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .refreshable { if !isSearchActive { await load() } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: loadFailed ? "wifi.slash" : (isSearchActive ? "magnifyingglass" : "person.2.fill"))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.coral.opacity(0.85))
                .frame(width: 76, height: 76)
                .background(Theme.coral.opacity(0.1))
                .clipShape(Circle())
            Text(loadFailed ? l10n.t(.addFriendError) : (isSearchActive ? l10n.t(.addFriendNoResults) : l10n.t(.talentEmpty)))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row

    private func row(_ user: SearchUserResult) -> some View {
        HStack(spacing: 14) {
            Avatar(colors: AppDataService.avatarPalette(for: user.id), initials: initials(user.name), imageURL: user.avatarUrl, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.name.isEmpty ? user.handle : user.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text(subtitle(user))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            actionButton(for: user)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func actionButton(for user: SearchUserResult) -> some View {
        if actioning.contains(user.id) {
            ProgressView().tint(Theme.coral).frame(width: 96, height: 36)
        } else {
            switch relationship(for: user) {
            case "friends":
                pill(text: l10n.t(.addFriendFriends), system: "checkmark", filled: false, enabled: false)
            case "request_sent":
                pill(text: l10n.t(.addFriendRequested), system: "clock", filled: false, enabled: false)
            case "request_received":
                Button { acceptIncoming(user) } label: {
                    pill(text: l10n.t(.friendRequestAccept), system: "checkmark", filled: true, enabled: true)
                }
                .buttonStyle(.plain)
            default:
                Button { addFriend(user) } label: {
                    pill(text: l10n.t(.addFriendAdd), system: "person.badge.plus", filled: true, enabled: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pill(text: String, system: String, filled: Bool, enabled: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).font(.system(size: 12, weight: .bold))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(filled ? .white : Theme.inkSecondary(for: colorScheme))
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(filled ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.cardSubtle(for: colorScheme)))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(filled ? Color.clear : Theme.hairline(for: colorScheme), lineWidth: 1))
        .opacity(enabled ? 1 : 0.65)
    }

    private func toastView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.ink(for: colorScheme).opacity(0.92))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                .padding(.bottom, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func relationship(for user: SearchUserResult) -> String {
        localRelationship[user.id] ?? user.relationship
    }

    private func subtitle(_ user: SearchUserResult) -> String {
        let parts = [user.handle, user.role].filter { !$0.isEmpty }
        let base = parts.joined(separator: " · ")
        guard !user.followers.isEmpty else { return base }
        return base.isEmpty ? user.followers : "\(base) · \(user.followers)"
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    // MARK: - Load (directory) & search

    @MainActor
    private func load() async {
        loadFailed = false
        do {
            people = try await data.loadTopTalent()
        } catch {
            print("⚠️ Top Talent load failed: \(error)")
            loadFailed = true
            people = []
        }
        isLoading = false
    }

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            await performSearch(trimmed)
        }
    }

    @MainActor
    private func performSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let res = try await data.searchUsers(query: q)
            if Task.isCancelled { return }
            searchResults = res
        } catch {
            if Task.isCancelled { return }
            print("⚠️ Top Talent search failed: \(error)")
            searchResults = []
        }
    }

    // MARK: - Actions

    private func addFriend(_ user: SearchUserResult) {
        guard !actioning.contains(user.id) else { return }
        actioning.insert(user.id)
        Task {
            defer { actioning.remove(user.id) }
            do {
                let status = try await data.sendFriendRequest(to: user.id, message: l10n.t(.friendRequestMessage))
                switch status {
                case "sent":
                    localRelationship[user.id] = "request_sent"
                    haptic(.success)
                    showToast(l10n.t(.addFriendSent))
                case "already_sent": localRelationship[user.id] = "request_sent"
                case "already_friends":
                    localRelationship[user.id] = "friends"
                    showToast(l10n.t(.addFriendAlreadyFriends))
                case "incoming_exists":
                    localRelationship[user.id] = "request_received"
                    showToast(l10n.t(.addFriendIncoming))
                default: break
                }
                await data.loadContacts()
            } catch {
                print("⚠️ Send friend request failed: \(error)")
                showToast(l10n.t(.addFriendError))
            }
        }
    }

    private func acceptIncoming(_ user: SearchUserResult) {
        guard let requestId = user.incomingRequestId, !actioning.contains(user.id) else { return }
        actioning.insert(user.id)
        Task {
            defer { actioning.remove(user.id) }
            do {
                let status = try await data.respondToFriendRequest(requestId: requestId, accept: true)
                if status == "accepted" {
                    localRelationship[user.id] = "friends"
                    haptic(.success)
                    showToast(l10n.t(.friendRequestAdded))
                }
                await data.loadContacts()
            } catch {
                print("⚠️ Accept request failed: \(error)")
                showToast(l10n.t(.addFriendError))
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = message }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
