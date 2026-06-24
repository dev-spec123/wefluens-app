//
//  CurateTalentView.swift
//  WeConnect
//
//  Admin curation of Top Talent: see/reorder/unfeature the featured creators, and
//  search all users to feature new ones. English-only (admin tool). All writes go
//  through is_admin-gated RPCs.
//

import SwiftUI

struct CurateTalentView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var featured: [FeaturedTalentRow] = []
    @State private var isLoading = true
    @State private var busy = false

    @State private var query = ""
    @State private var results: [SearchUserResult] = []
    @State private var searchTask: Task<Void, Never>? = nil

    private var featuredIds: Set<UUID> { Set(featured.map(\.id)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                featuredSection
                searchSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Curate Top Talent")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFeatured() }
    }

    // MARK: - Featured

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("FEATURED (in order)")
            if isLoading {
                ProgressView().tint(Theme.coral).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if featured.isEmpty {
                Text("No featured creators yet. Search below to add some.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(featured.enumerated()), id: \.element.id) { index, person in
                        featuredRow(person, index: index)
                        if index < featured.count - 1 {
                            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 60)
                        }
                    }
                }
                .padding(.vertical, 4)
                .cardStyle()
            }
        }
    }

    private func featuredRow(_ person: FeaturedTalentRow, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.coral)
                .frame(width: 22)
            Avatar(colors: AppDataService.avatarPalette(for: person.id), initials: initials(person.name), imageURL: person.avatarUrl, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name.isEmpty ? person.handle : person.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text([person.handle, person.role].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            Button { move(index, by: -1) } label: { arrow("chevron.up") }
                .disabled(index == 0 || busy)
            Button { move(index, by: 1) } label: { arrow("chevron.down") }
                .disabled(index == featured.count - 1 || busy)
            Button { unfeature(person) } label: {
                Image(systemName: "star.slash.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.coral)
            }
            .disabled(busy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            .frame(width: 30, height: 30)
            .background(Theme.cardSubtle(for: colorScheme))
            .clipShape(Circle())
    }

    // MARK: - Search to feature

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("ADD A CREATOR")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSecondary(for: colorScheme))
                TextField("Search by name, @handle, or email", text: $query)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(Theme.card(for: colorScheme))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            .onChange(of: query) { _, v in scheduleSearch(v) }

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, user in
                        searchRow(user)
                        if index < results.count - 1 {
                            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 60)
                        }
                    }
                }
                .padding(.vertical, 4)
                .cardStyle()
            }
        }
    }

    private func searchRow(_ user: SearchUserResult) -> some View {
        HStack(spacing: 12) {
            Avatar(colors: AppDataService.avatarPalette(for: user.id), initials: initials(user.name), imageURL: user.avatarUrl, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name.isEmpty ? user.handle : user.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text([user.handle, user.role].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            Spacer()
            if featuredIds.contains(user.id) {
                Text("Featured")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            } else {
                Button { feature(user) } label: {
                    Text("Feature")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Theme.sunset).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            .tracking(1)
            .padding(.leading, 4)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let r = (f + l).uppercased()
        return r.isEmpty ? "?" : r
    }

    // MARK: - Actions

    @MainActor
    private func loadFeatured() async {
        do { featured = try await data.adminListFeaturedTalent() }
        catch { print("⚠️ load featured talent failed: \(error)") }
        isLoading = false
    }

    private func feature(_ user: SearchUserResult) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            let nextRank = (featured.map(\.featuredRank).max() ?? 0) + 1
            do {
                try await data.adminSetFeaturedTalent(userId: user.id, rank: nextRank)
                await loadFeatured()
            } catch { print("⚠️ feature failed: \(error)") }
        }
    }

    private func unfeature(_ person: FeaturedTalentRow) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await data.adminSetFeaturedTalent(userId: person.id, rank: nil)
                await loadFeatured()
            } catch { print("⚠️ unfeature failed: \(error)") }
        }
    }

    /// Swaps a featured item's rank with its neighbor (delta -1 up / +1 down).
    private func move(_ index: Int, by delta: Int) {
        let target = index + delta
        guard !busy, featured.indices.contains(index), featured.indices.contains(target) else { return }
        busy = true
        let a = featured[index], b = featured[target]
        Task {
            defer { busy = false }
            do {
                try await data.adminSetFeaturedTalent(userId: a.id, rank: b.featuredRank)
                try await data.adminSetFeaturedTalent(userId: b.id, rank: a.featuredRank)
                await loadFeatured()
            } catch { print("⚠️ reorder failed: \(error)") }
        }
    }

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            do {
                let res = try await data.searchUsers(query: q)
                if !Task.isCancelled { results = res }
            } catch { if !Task.isCancelled { results = [] } }
        }
    }
}
