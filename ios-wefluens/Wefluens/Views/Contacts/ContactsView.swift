//
//  ContactsView.swift
//  Wefluens
//

import SwiftUI

struct ContactsView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @State private var showRequestDetail: UUID? = nil

    private var contacts: [Contact] { data.contacts }
    private var requests: [FriendRequest] { data.friendRequests }

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.handle.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Contacts grouped by first letter, sorted alphabetically.
    private var grouped: [(letter: String, items: [Contact])] {
        let sorted = filtered.sorted { $0.name < $1.name }
        let dict = Dictionary(grouping: sorted) { String($0.name.prefix(1)).uppercased() }
        return dict.keys.sorted().map { (letter: $0, items: dict[$0] ?? []) }
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
                                        ContactRow(contact: contact)
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
            .navigationDestination(for: UUID.self) { id in
                if let contact = contacts.first(where: { $0.id == id }) {
                    ContactDetailView(contact: contact)
                }
            }
        }
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
                        NavigationLink {
                            FriendRequestDetailView(request: req)
                        } label: {
                            FriendRequestRow(request: req)
                        }
                        .buttonStyle(.plain)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Theme.card(for: colorScheme))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickAction(icon: "person.badge.plus", title: l10n.t(.contactsInvite))
            quickAction(icon: "star.fill", title: l10n.t(.contactsTopTalent))
            quickAction(icon: "building.2.fill", title: l10n.t(.contactsBrands))
        }
    }

    private func quickAction(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 48, height: 48)
                .background(Theme.coral.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle(cornerRadius: 18)
    }
}

// MARK: - Friend Request Row

private struct FriendRequestRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let request: FriendRequest

    var body: some View {
        HStack(spacing: 14) {
            Avatar(colors: request.avatarColors, initials: request.initials, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(request.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(request.requestMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.coral)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

// MARK: - Friend Request Detail View

struct FriendRequestDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let request: FriendRequest
    @State private var accepted: Bool = false
    @State private var declined: Bool = false

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
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0x2AD17E))
                    Text("Friend added!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x2AD17E))
                }
                .padding(.top, 8)
            } else if declined {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    Text("Declined")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
                .padding(.top, 8)
            } else {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            declined = true
                        }
                    } label: {
                        Text(l10n.t(.friendRequestDecline))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .frame(width: 140)
                            .padding(.vertical, 14)
                            .background(Theme.card(for: colorScheme))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                    }

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            accepted = true
                        }
                    } label: {
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
}

// MARK: - Contact Row

private struct ContactRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let contact: Contact

    var body: some View {
        HStack(spacing: 14) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, size: 50, isOnline: contact.isOnline)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
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
