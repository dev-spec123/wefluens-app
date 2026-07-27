//
//  EventDetailView.swift
//  WeConnect
//
//  The detail screen for a published Discover event, with the sign-up / cancel
//  bar. Mirrors CampaignDetailView; the differences are that an event is dated
//  and placed (When / Where) and that capacity is enforced — a full event shows
//  a disabled button rather than letting the RPC fail.
//

import SwiftUI

/// Navigation route for an event. Campaigns already push a bare `UUID`, so events
/// need their own Hashable type — otherwise both would match the same
/// `navigationDestination(for: UUID.self)` and the wrong screen would open.
struct EventRoute: Hashable {
    let id: UUID
}

/// "Sat, 12 Jul · 7:00 PM" — the one date style used across the event surfaces.
func formatEventDate(_ date: Date?, fallback: String) -> String {
    guard let date else { return fallback }
    let f = DateFormatter()
    f.dateFormat = "EEE, d MMM · h:mm a"
    return f.string(from: date)
}

struct EventDetailView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let event: Event

    @State private var signedUp = false
    @State private var showCancelConfirm = false
    @State private var busy = false
    @State private var signUpError: String?

    /// Full only matters when the user isn't already in — their own slot is theirs.
    private var isFull: Bool { event.isFull && !signedUp }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                quickStats
                aboutCard
            }
            .padding(.bottom, 120)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        // Seed from the row's own flag, then refine against my live signups so
        // leaving and returning stays in sync (mirrors CampaignDetailView).
        .onAppear {
            signedUp = event.signedUp
            Task {
                if let ids = try? await data.loadMyEventSignups() {
                    signedUp = ids.contains(event.id)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.25))
                    .clipShape(Circle())
            }
            .padding(.leading, 18)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) { signUpBar }
        .confirmationDialog(
            l10n.t(.eventDetailCancelConfirm),
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.eventDetailCancelSignup), role: .destructive) { cancel() }
            Button(l10n.t(.adminCancel), role: .cancel) { }
        }
        .alert(l10n.t(.discoverSignUpFailed), isPresented: Binding(
            get: { signUpError != nil },
            set: { if !$0 { signUpError = nil } }
        )) {
            Button("OK", role: .cancel) { signUpError = nil }
        }
    }

    // MARK: - Actions

    private func signUp() {
        guard !busy, !isFull else { return }
        busy = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { signedUp = true }
        Task {
            defer { busy = false }
            do {
                try await data.signUpForEvent(event.id)
                await data.loadDiscover()
            } catch {
                withAnimation { signedUp = false }   // roll back optimistic UI
                signUpError = error.localizedDescription
            }
        }
    }

    private func cancel() {
        guard !busy else { return }
        busy = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { signedUp = false }
        Task {
            defer { busy = false }
            do {
                try await data.cancelEventSignup(event.id)
                await data.loadDiscover()
            } catch {
                withAnimation { signedUp = true }    // roll back optimistic UI
                signUpError = error.localizedDescription
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: event.colors.map { Color(hex: $0) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let iconUrl = event.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                .opacity(0.9)
            } else {
                Image(systemName: event.symbol)
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(.white.opacity(0.15))
                    .offset(x: 110, y: 20)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                if !event.brand.isEmpty {
                    Text(event.brand.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(2)
                }
                Text(event.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(22)
        }
        .frame(height: 260)
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            stat(icon: "calendar",
                 value: formatEventDate(event.startsAt, fallback: l10n.t(.eventDetailTBA)),
                 label: l10n.t(.eventDetailWhen))
            stat(icon: "mappin.and.ellipse",
                 value: event.location.isEmpty ? l10n.t(.eventDetailTBA) : event.location,
                 label: l10n.t(.eventDetailWhere))
            stat(icon: "person.2.fill",
                 value: event.spotsLeft.map(String.init) ?? l10n.t(.eventDetailOpenToAll),
                 label: l10n.t(.eventDetailSpots))
        }
        .padding(.horizontal, 18)
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.coral)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .cardStyle(cornerRadius: 18)
    }

    @ViewBuilder
    private var aboutCard: some View {
        if !event.description.isEmpty || !event.tags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.t(.eventDetailAbout))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        .lineSpacing(4)
                }
                if !event.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(event.tags, id: \.self) { TagChip(text: $0) }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardStyle()
            .padding(.horizontal, 18)
        }
    }

    private var signUpBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.signupCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(l10n.t(.discoverParticipants))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
            Spacer()
            if signedUp {
                Button { showCancelConfirm = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text(l10n.t(.eventDetailSignedUp))
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(Theme.coral.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.coral, lineWidth: 1.5))
                }
            } else if isFull {
                // Capacity is enforced server-side; showing it disabled here means
                // the user never taps into a guaranteed failure.
                Text(l10n.t(.discoverEventFull))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 15)
                    .background(Theme.inkTertiary(for: colorScheme).opacity(0.15), in: Capsule())
            } else {
                Button { signUp() } label: {
                    Text(l10n.t(.eventDetailSignUp))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 15)
                        .background(Theme.sunset)
                        .clipShape(Capsule())
                        .shadow(color: Theme.coral.opacity(0.4), radius: 12, y: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}
