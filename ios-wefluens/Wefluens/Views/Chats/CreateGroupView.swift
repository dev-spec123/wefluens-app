//
//  CreateGroupView.swift
//  Wefluens
//
//  Multi-select contacts to create a group chat.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var groupName: String = ""

    private let contacts = SampleData.contacts

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.role.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedContacts: [Contact] {
        contacts.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            selectedBar
            list
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .frame(width: 40, height: 40)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.createGroupTitle))
                    .font(.system(size: 18, weight: .bold))
                Text(contacts.count.formatted() + " " + l10n.t(.contactsSubtitle))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                // In a real app, create the group and dismiss
                dismiss()
            } label: {
                Text(l10n.t(.createGroupCreate))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedIDs.count >= 2 ? Theme.coral : Theme.inkTertiary(for: colorScheme))
            }
            .disabled(selectedIDs.count < 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var selectedBar: some View {
        if !selectedContacts.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Text("\(selectedContacts.count) \(l10n.t(.createGroupSelected))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .padding(.leading, 16)

                    ForEach(selectedContacts) { contact in
                        selectedChip(contact)
                    }
                }
                .padding(.vertical, 10)
            }
            .background(Theme.coral.opacity(0.06))
        }
    }

    private func selectedChip(_ contact: Contact) -> some View {
        HStack(spacing: 6) {
            Avatar(colors: contact.avatarColors, initials: contact.initials, size: 28)
            Text(contact.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Button {
                selectedIDs.remove(contact.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card(for: colorScheme))
        .clipShape(Capsule())
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    TextField(l10n.t(.createGroupSearch), text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.card(for: colorScheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Contact list
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, contact in
                        Button {
                            if selectedIDs.contains(contact.id) {
                                selectedIDs.remove(contact.id)
                            } else {
                                selectedIDs.insert(contact.id)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Avatar(colors: contact.avatarColors, initials: contact.initials, size: 48, isOnline: contact.isOnline)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(contact.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.ink(for: colorScheme))
                                    Text(contact.role)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                                }

                                Spacer()

                                ZStack {
                                    Circle()
                                        .stroke(selectedIDs.contains(contact.id) ? Theme.coral : Theme.hairline(for: colorScheme), lineWidth: 2)
                                        .frame(width: 24, height: 24)

                                    if selectedIDs.contains(contact.id) {
                                        Circle()
                                            .fill(Theme.coral)
                                            .frame(width: 16, height: 16)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < filtered.count - 1 {
                            Divider()
                                .background(Theme.hairline(for: colorScheme))
                                .padding(.leading, 76)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CreateGroupView()
        .environment(LocalizationManager())
}
