//
//  AddFriendView.swift
//  WeConnect
//
//  Search existing platform users by email or @handle and send a friend
//  request (application-based). 100% database — never sends any email.
//

import SwiftUI

struct AddFriendView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [SearchUserResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    /// The curated Top Talent list, shown as suggestions when no search is active.
    @State private var suggestions: [SearchUserResult] = []
    @State private var loadingSuggestions = true

    /// Local relationship overrides applied immediately after an action.
    @State private var localRelationship: [UUID: String] = [:]
    @State private var actioning: Set<UUID> = []

    @State private var toast: String? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 16) {
                    searchField
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                if let toast {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Theme.ink(for: colorScheme).opacity(0.92))
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 30)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(l10n.t(.contactsAddFriend))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t(.settingsDone)) { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
            }
            .task { await loadSuggestions() }
        }
    }

    @MainActor
    private func loadSuggestions() async {
        do { suggestions = try await data.loadTopTalent() }
        catch { suggestions = [] }
        loadingSuggestions = false
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.addFriendSearchPlaceholder), text: $query)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { runSearchNow() }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    searchTask?.cancel()
                    isSearching = false
                } label: {
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
        .onChange(of: query) { _, newValue in
            scheduleSearch(newValue)
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            if loadingSuggestions && suggestions.isEmpty {
                ProgressView().tint(Theme.coral).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if suggestions.isEmpty {
                centeredState(icon: "person.2.fill", title: l10n.t(.addFriendHint), subtitle: nil)
            } else {
                peopleList(suggestions, header: l10n.t(.contactsTopTalent))
            }
        } else if isSearching && results.isEmpty {
            VStack(spacing: 14) {
                ProgressView().tint(Theme.coral).scaleEffect(1.1)
                Text(l10n.t(.addFriendSearching))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty {
            centeredState(icon: "magnifyingglass", title: l10n.t(.addFriendNoResults), subtitle: nil)
        } else {
            peopleList(results, header: nil)
        }
    }

    private func peopleList(_ people: [SearchUserResult], header: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let header {
                    Text(header.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        .tracking(1)
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, user in
                        resultRow(user)
                        if index < people.count - 1 {
                            Divider()
                                .background(Theme.hairline(for: colorScheme))
                                .padding(.leading, 76)
                        }
                    }
                }
                .padding(.vertical, 6)
                .cardStyle()
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func centeredState(icon: String, title: String, subtitle: String?) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.coral.opacity(0.85))
                .frame(width: 76, height: 76)
                .background(Theme.coral.opacity(0.1))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result row

    private func resultRow(_ user: SearchUserResult) -> some View {
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
            ProgressView()
                .tint(Theme.coral)
                .frame(width: 96, height: 36)
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

    // MARK: - Helpers

    private func relationship(for user: SearchUserResult) -> String {
        localRelationship[user.id] ?? user.relationship
    }

    private func subtitle(_ user: SearchUserResult) -> String {
        let parts = [user.handle, user.role].filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    // MARK: - Search

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            await performSearch(trimmed)
        }
    }

    private func runSearchNow() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        searchTask = Task { await performSearch(trimmed) }
    }

    @MainActor
    private func performSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let res = try await data.searchUsers(query: q)
            if Task.isCancelled { return }
            results = res
        } catch {
            if Task.isCancelled { return }
            print("⚠️ User search failed: \(error)")
            results = []
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
                case "already_sent":
                    localRelationship[user.id] = "request_sent"
                case "already_friends":
                    localRelationship[user.id] = "friends"
                    showToast(l10n.t(.addFriendAlreadyFriends))
                case "incoming_exists":
                    localRelationship[user.id] = "request_received"
                    showToast(l10n.t(.addFriendIncoming))
                default:
                    break
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

    // MARK: - Toast & haptics

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
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

#Preview {
    AddFriendView()
        .environment(AppDataService(userId: nil))
        .environment(LocalizationManager())
}
