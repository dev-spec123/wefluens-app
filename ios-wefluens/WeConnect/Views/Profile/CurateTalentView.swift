//
//  CurateTalentView.swift
//  WeConnect
//
//  Admin curation of Top Talent. Shows the featured creators (ordered, with
//  reorder/unfeature) and a full list of all users to feature from, with a search
//  filter. English-only (admin tool). Writes go through is_admin-gated RPCs.
//

import SwiftUI

struct CurateTalentView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var people: [ProfileCurationRow] = []
    @State private var isLoading = true
    @State private var busy = false
    @State private var errorText: String?
    @State private var query = ""

    private var featured: [ProfileCurationRow] {
        people.filter { $0.featuredRank != nil }
            .sorted { ($0.featuredRank ?? 0) < ($1.featuredRank ?? 0) }
    }
    private var others: [ProfileCurationRow] {
        let base = people.filter { $0.featuredRank == nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = q.isEmpty ? base : base.filter {
            displayName($0).localizedCaseInsensitiveContains(q) ||
            ($0.handle ?? "").localizedCaseInsensitiveContains(q) ||
            ($0.role ?? "").localizedCaseInsensitiveContains(q)
        }
        return filtered.sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                    ProgressView().tint(Theme.coral).frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    if !featured.isEmpty {
                        group("FEATURED (in order)") {
                            ForEach(Array(featured.enumerated()), id: \.element.id) { index, person in
                                personRow(person, featuredIndex: index)
                                if index < featured.count - 1 { divider }
                            }
                        }
                    }
                    searchBar
                    group(query.isEmpty ? "ALL USERS" : "RESULTS") {
                        if others.isEmpty {
                            Text(people.isEmpty ? "No users found." : "No matches.")
                                .font(.system(size: 14)).foregroundStyle(Theme.inkSecondary(for: colorScheme))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                        } else {
                            ForEach(Array(others.enumerated()), id: \.element.id) { index, person in
                                personRow(person, featuredIndex: nil)
                                if index < others.count - 1 { divider }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Curate Top Talent")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField("Search users", text: $query)
                .font(.system(size: 16)).foregroundStyle(Theme.ink(for: colorScheme))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Theme.card(for: colorScheme)).clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
    }

    private func personRow(_ person: ProfileCurationRow, featuredIndex: Int?) -> some View {
        HStack(spacing: 12) {
            if let featuredIndex {
                Text("\(featuredIndex + 1)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.coral).frame(width: 20)
            }
            Avatar(colors: AppDataService.avatarPalette(for: person.id), initials: initials(displayName(person)), imageURL: person.avatarUrl, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(person)).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme)).lineLimit(1)
                Text([person.handle ?? "", person.role ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(Theme.inkSecondary(for: colorScheme)).lineLimit(1)
            }
            Spacer()
            if let featuredIndex {
                Button { move(featuredIndex, by: -1) } label: { arrow("chevron.up") }
                    .disabled(featuredIndex == 0 || busy)
                Button { move(featuredIndex, by: 1) } label: { arrow("chevron.down") }
                    .disabled(featuredIndex == featured.count - 1 || busy)
                Button { setFeatured(person, rank: nil) } label: {
                    Image(systemName: "star.slash.fill").font(.system(size: 15)).foregroundStyle(Theme.coral)
                }.disabled(busy)
            } else {
                Button { setFeatured(person, rank: (featured.map { $0.featuredRank ?? 0 }.max() ?? 0) + 1) } label: {
                    Text("Feature").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 34).background(Theme.sunset).clipShape(Capsule())
                }.buttonStyle(.plain).disabled(busy)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1).padding(.leading, 4)
            VStack(spacing: 0) { content() }.padding(.vertical, 4).cardStyle()
        }
    }

    private var divider: some View {
        Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 60)
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            .frame(width: 30, height: 30).background(Theme.cardSubtle(for: colorScheme)).clipShape(Circle())
    }

    private func displayName(_ p: ProfileCurationRow) -> String {
        let n = (p.name ?? "").isEmpty ? (p.handle ?? "") : (p.name ?? "")
        return n.isEmpty ? "User" : n
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let r = (f + l).uppercased()
        return r.isEmpty ? "?" : r
    }

    // MARK: - Actions

    @MainActor private func reload() async {
        do { people = try await data.loadProfilesForCuration(); errorText = nil }
        catch { errorText = "Couldn't load users: \(error.localizedDescription)" }
        isLoading = false
    }

    private func setFeatured(_ person: ProfileCurationRow, rank: Int?) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await data.adminSetFeaturedTalent(userId: person.id, rank: rank); await reload() }
            catch { errorText = "Couldn't update: \(error.localizedDescription)" }
        }
    }

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
                await reload()
            } catch { errorText = "Couldn't reorder: \(error.localizedDescription)" }
        }
    }
}
