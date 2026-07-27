//
//  EventSignupsView.swift
//  WeConnect
//
//  The participant roster for one event — who signed up, newest first. Reached
//  from ManageEventsView. Admin-only: the read is is_admin-gated server-side, so
//  influencers only ever see the aggregate count on Discover. English-only
//  (admin tool), matching the other management screens.
//

import SwiftUI

struct EventSignupsView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    let event: Event

    @State private var signups: [EventSignupRow] = []
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if isLoading {
                    ProgressView().tint(Theme.coral)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if signups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        Text(event.published
                             ? "Nobody has signed up yet."
                             : "This event is still a draft — publish it so creators can sign up.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PARTICIPANTS (\(signups.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                            .tracking(1).padding(.leading, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(signups.enumerated()), id: \.element.id) { index, person in
                                signupRow(person)
                                if index < signups.count - 1 {
                                    Divider()
                                        .background(Theme.hairline(for: colorScheme))
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .cardStyle()
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Signed Up")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .refreshable { await reload() }
    }

    /// Event title + how full it is, so the roster reads in context.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Text(capacityLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
    }

    private var capacityLine: String {
        if let capacity = event.capacity {
            return "\(signups.count) of \(capacity) spots taken"
        }
        return "\(signups.count) signed up · no limit"
    }

    private func signupRow(_ person: EventSignupRow) -> some View {
        HStack(spacing: 12) {
            Avatar(
                colors: AppDataService.avatarPalette(for: person.id),
                initials: initials(displayName(person)),
                imageURL: person.avatarUrl,
                size: 40
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(person))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text(secondaryLine(person))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            if let when = person.signedUpAt {
                Text(Self.dayFormatter.string(from: when))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    // MARK: - Helpers

    private func displayName(_ p: EventSignupRow) -> String {
        if !p.name.isEmpty { return p.name }
        if !p.handle.isEmpty { return p.handle }
        return p.email.isEmpty ? "User" : p.email
    }

    /// "@handle · role" when we have them, else the email — whatever identifies
    /// the participant for an admin who needs to reach them.
    private func secondaryLine(_ p: EventSignupRow) -> String {
        let parts = [p.handle, p.role].filter { !$0.isEmpty }
        return parts.isEmpty ? p.email : parts.joined(separator: " · ")
    }

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    @MainActor private func reload() async {
        do {
            signups = try await data.loadEventSignups(eventId: event.id)
            errorText = nil
        } catch {
            errorText = "Couldn't load signups: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
