//
//  ContactsView.swift
//  WeConnect
//

import SwiftUI

private enum ContactFilter { case all, topTalent, brands }

struct ContactsView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @State private var showRequestDetail: UUID? = nil
    @State private var showAddFriend: Bool = false
    @State private var filterMode: ContactFilter = .all

    private var contacts: [Contact] { data.contacts }
    private var requests: [FriendRequest] { data.friendRequests }

    private var filtered: [Contact] {
        var list = contacts
        switch filterMode {
        case .all: break
        case .brands: list = list.filter { $0.role.localizedCaseInsensitiveContains("brand") }
        case .topTalent: list = list.filter { !$0.role.localizedCaseInsensitiveContains("brand") }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return list }
        return list.filter { contact in
            let remark = data.remark(for: contact.id) ?? ""
            return contact.name.localizedCaseInsensitiveContains(trimmed) ||
                remark.localizedCaseInsensitiveContains(trimmed) ||
                contact.handle.localizedCaseInsensitiveContains(trimmed) ||
                contact.role.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// The name used for sorting / sectioning a contact: its remark when set,
    /// otherwise the real name (so a 备注 also moves the friend in the A–Z list).
    private func sortName(for contact: Contact) -> String {
        data.remark(for: contact.id) ?? contact.name
    }

    /// Pinyin first letter (A–Z) of a display name for A–Z sectioning. Chinese is
    /// transliterated to Latin via Foundation, diacritics stripped; anything that
    /// isn't an A–Z letter (digits, symbols, emoji) buckets under "#".
    private func sectionLetter(for name: String) -> String {
        let latin = name
            .applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)
        guard let first = (latin ?? name).first.map({ String($0).uppercased() }),
              let scalar = first.unicodeScalars.first,
              ("A"..."Z").contains(scalar) else { return "#" }
        return first
    }

    /// Contacts grouped into A–Z sections by pinyin first letter, headers sorted
    /// A..Z with "#" (non-letters) pushed to the end.
    private var grouped: [(letter: String, items: [Contact])] {
        let sorted = filtered.sorted {
            sortName(for: $0).localizedCaseInsensitiveCompare(sortName(for: $1)) == .orderedAscending
        }
        let dict = Dictionary(grouping: sorted) { sectionLetter(for: sortName(for: $0)) }
        let letters = dict.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }
        return letters.map { (letter: $0, items: dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ScreenHeader(
                        title: l10n.t(.contactsTitle),
                        subtitle: "\(contacts.count) \(l10n.t(.contactsSubtitle))"
                    )
                    .padding(.top, 8)

                    searchBar
                    quickActions
                    friendRequestsSection

                    ForEach(grouped, id: \.letter) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.letter)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.coral)
                                .padding(.leading, 6)

                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, contact in
                                    NavigationLink(value: contact.id) {
                                        ContactRow(contact: contact, displayName: data.displayName(for: contact))
                                    }
                                    .buttonStyle(.plain)
                                    if index < group.items.count - 1 {
                                        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 76)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .cardStyle()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await data.loadContacts() }
            .navigationDestination(for: UUID.self) { id in
                if let contact = contacts.first(where: { $0.id == id }) {
                    ContactDetailView(contact: contact)
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .alert(l10n.t(.friendAcceptedTitle), isPresented: acceptedAlertBinding) {
                Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
            } message: {
                Text(acceptedMessage)
            }
            .onAppear {
                Task { await data.loadContacts() }
            }
        }
    }

    /// True while there are unseen "your request was accepted" notifications.
    /// Dismissing clears them server-side.
    private var acceptedAlertBinding: Binding<Bool> {
        Binding(
            get: { !data.friendAcceptedNames.isEmpty },
            set: { isShown in
                if !isShown { Task { await data.markAcceptancesSeen() } }
            }
        )
    }

    private var acceptedMessage: String {
        let names = data.friendAcceptedNames.joined(separator: ", ")
        return "\(names) \(l10n.t(.friendAcceptedMessage))"
    }

    // MARK: - Friend Requests Section

    private var friendRequestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !requests.isEmpty {
                Text(l10n.t(.contactsNewFriends).uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    .tracking(1)
                    .padding(.leading, 4)

                VStack(spacing: 0) {
                    ForEach(Array(requests.enumerated()), id: \.element.id) { index, req in
                        FriendRequestRow(request: req)
                        if index < requests.count - 1 {
                            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 76)
                        }
                    }
                }
                .padding(.vertical, 6)
                .cardStyle()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.contactsSearch), text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
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
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                showAddFriend = true
            } label: {
                quickAction(icon: "person.badge.plus", title: l10n.t(.contactsAddFriend), active: false)
            }
            .buttonStyle(.plain)
            Button {
                filterMode = (filterMode == .topTalent) ? .all : .topTalent
            } label: {
                quickAction(icon: "star.fill", title: l10n.t(.contactsTopTalent), active: filterMode == .topTalent)
            }
            .buttonStyle(.plain)
            Button {
                filterMode = (filterMode == .brands) ? .all : .brands
            } label: {
                quickAction(icon: "building.2.fill", title: l10n.t(.contactsBrands), active: filterMode == .brands)
            }
            .buttonStyle(.plain)
        }
    }

    private func quickAction(icon: String, title: String, active: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(active ? .white : Theme.coral)
                .frame(width: 48, height: 48)
                .background(active ? AnyShapeStyle(Theme.sunset) : AnyShapeStyle(Theme.coral.opacity(0.1)))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Theme.coral : Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(cornerRadius: 18)
    }
}

// MARK: - Friend Request Row

private struct FriendRequestRow: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    let request: FriendRequest
    @State private var busy = false

    var body: some View {
        HStack(spacing: 12) {
            Avatar(colors: request.avatarColors, initials: request.initials, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(request.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text(request.requestMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if busy {
                ProgressView().tint(Theme.coral)
            } else {
                HStack(spacing: 8) {
                    Button { respond(accept: false) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .frame(width: 36, height: 36)
                            .background(Theme.card(for: colorScheme))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Button { respond(accept: true) } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.sunset)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    /// Accept/decline directly from the row (no drill-in), matching the RN flow.
    /// On success the request disappears once contacts reload.
    private func respond(accept: Bool) {
        guard !busy else { return }
        busy = true
        Task {
            do {
                try await data.respondToFriendRequest(requestId: request.id, accept: accept)
                if accept { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                await data.loadContacts()
            } catch {
                print("⚠️ respond_friend_request failed: \(error)")
            }
            busy = false
        }
    }
}

// MARK: - Friend Request Detail View

struct FriendRequestDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let request: FriendRequest
    @State private var accepted: Bool = false
    @State private var declined: Bool = false
    @State private var isProcessing: Bool = false
    @State private var errorText: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Avatar(colors: request.avatarColors, initials: request.initials, size: 96, isOnline: false)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 10)

            VStack(spacing: 6) {
                Text(request.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(request.handle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            TagChip(text: request.role, filled: true)

            Text(request.requestMessage)
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            if accepted {
                resultLabel(icon: "checkmark.circle.fill", tint: Color(hex: 0x2AD17E), text: l10n.t(.friendRequestAdded))
            } else if declined {
                resultLabel(icon: "xmark.circle.fill", tint: Theme.inkTertiary(for: colorScheme), text: l10n.t(.friendRequestDeclined))
            } else {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button { respond(accept: false) } label: {
                            Text(l10n.t(.friendRequestDecline))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                                .frame(width: 140)
                                .padding(.vertical, 14)
                                .background(Theme.card(for: colorScheme))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                        }

                        Button { respond(accept: true) } label: {
                            Text(l10n.t(.friendRequestAccept))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 140)
                                .padding(.vertical, 14)
                                .background(Theme.sunset)
                                .clipShape(Capsule())
                                .shadow(color: Theme.coral.opacity(0.35), radius: 12, y: 6)
                        }
                    }
                    .disabled(isProcessing)
                    .opacity(isProcessing ? 0.6 : 1)

                    if isProcessing {
                        ProgressView().tint(Theme.coral)
                    }
                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }

    private func resultLabel(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.top, 8)
    }

    /// Calls respond_friend_request, refreshes data (so the new friend appears
    /// and the request disappears), then dismisses. Pure DB — no email.
    private func respond(accept: Bool) {
        guard !isProcessing else { return }
        isProcessing = true
        errorText = nil
        Task {
            do {
                try await data.respondToFriendRequest(requestId: request.id, accept: accept)
                await data.loadContacts()
                isProcessing = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    if accept { accepted = true } else { declined = true }
                }
                if accept { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                try? await Task.sleep(for: .seconds(1.1))
                dismiss()
            } catch {
                isProcessing = false
                errorText = l10n.t(.friendRequestError)
                print("⚠️ respond_friend_request failed: \(error)")
            }
        }
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let contact: Contact
    /// The name to show: the friend's remark (备注) when set, else their real name.
    let displayName: String

    var body: some View {
        HStack(spacing: 14) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, imageURL: contact.avatarUrl, size: 50, isOnline: contact.isOnline)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(contact.role)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(contact.followers)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(contact.platform)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

#Preview {
    ContactsView()
        .environment(LocalizationManager())
}
