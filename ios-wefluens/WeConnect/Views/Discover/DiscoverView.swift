//
//  DiscoverView.swift
//  WeConnect
//

import SwiftUI

struct DiscoverView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    private var brands: [Brand] { data.brands }
    private var campaigns: [Campaign] { data.campaigns }

    /// "精选 / Featured" = brands an admin has featured (featured_rank not null), in rank order.
    private var featuredBrands: [Brand] {
        data.brands.filter { $0.featuredRank != nil }
            .sorted { ($0.featuredRank ?? 0) < ($1.featuredRank ?? 0) }
    }

    /// "热门品牌 / Hot" = all brands sorted by application count (most-applied first),
    /// with name as a stable tiebreaker.
    private var hotBrands: [Brand] {
        data.brands.sorted {
            if $0.applicationCount != $1.applicationCount {
                return $0.applicationCount > $1.applicationCount
            }
            return $0.name < $1.name
        }
    }

    @State private var selectedFilter: String = "All"
    @State private var selectedBrand: String? = nil
    /// Server-seeded set of applied campaign ids (source of truth = list_my_applications).
    /// Seeded on appear; mutated optimistically by the apply/withdraw toggle.
    @State private var appliedIds: Set<UUID> = []
    @State private var applyError: String? = nil

    private var filters: [(key: L10n, label: String)] {
        [
            (.filterAll, l10n.t(.filterAll)),
            (.filterBeauty, l10n.t(.filterBeauty)),
            (.filterFashion, l10n.t(.filterFashion)),
            (.filterWellness, l10n.t(.filterWellness)),
            (.filterTech, l10n.t(.filterTech)),
        ]
    }

    private var visibleCampaigns: [Campaign] {
        var list = campaigns
        // Brand filter — tapping a brand card narrows to that brand.
        if let selectedBrand {
            list = list.filter { $0.brand == selectedBrand }
        }
        // Category chip filter — map the localized chip to an English match term so
        // it works regardless of the app's language.
        if selectedFilter != l10n.t(.filterAll) {
            let term: String?
            switch selectedFilter {
            case l10n.t(.filterBeauty): term = "beauty"
            case l10n.t(.filterFashion): term = "fashion"
            case l10n.t(.filterWellness): term = "wellness"
            case l10n.t(.filterTech): term = "tech"
            default: term = nil
            }
            if let term {
                list = list.filter { c in
                    c.tags.contains { $0.lowercased().contains(term) }
                        || c.title.lowercased().contains(term)
                        || c.brand.lowercased().contains(term)
                }
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(
                        title: l10n.t(.discoverTitle),
                        subtitle: l10n.t(.discoverSubtitle)
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 18)

                    filterBar
                    featuredSection
                    hotSection
                    campaignsSection
                }
                .padding(.bottom, 24)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { id in
                if let campaign = campaigns.first(where: { $0.id == id }) {
                    CampaignDetailView(campaign: campaign)
                }
            }
            // Refresh on each appearance (e.g. returning from the admin curation
            // panel) so featured-brand changes show without an app restart. The
            // applied set is the server's truth, re-seeded each time.
            .onAppear { Task { await reload() } }
            .refreshable { await reload() }
            .alert(l10n.t(.discoverApplyFailed), isPresented: Binding(
                get: { applyError != nil },
                set: { if !$0 { applyError = nil } }
            )) {
                Button("OK", role: .cancel) { applyError = nil }
            }
        }
    }

    private func reload() async {
        await data.loadDiscover()
        do {
            let ids = try await data.loadMyApplications()
            appliedIds = Set(ids)
        } catch {
            // Fall back to seeding from the campaigns' own `applied` flag if the
            // dedicated applications read fails — the server still drives state.
            appliedIds = Set(data.campaigns.filter { $0.applied }.map { $0.id })
        }
    }

    // MARK: - Apply / withdraw

    private func isApplied(_ campaign: Campaign) -> Bool {
        appliedIds.contains(campaign.id) || campaign.applied
    }

    private func toggleApply(_ campaign: Campaign) {
        let currentlyApplied = isApplied(campaign)
        // Optimistic UI; reconcile with the server on completion.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if currentlyApplied { appliedIds.remove(campaign.id) }
            else { appliedIds.insert(campaign.id) }
        }
        Task {
            do {
                if currentlyApplied {
                    try await data.withdrawFromCampaign(campaign.id)
                } else {
                    try await data.applyToCampaign(campaign.id)
                }
                await reload()
            } catch {
                // Roll back the optimistic change and surface the error.
                withAnimation {
                    if currentlyApplied { appliedIds.insert(campaign.id) }
                    else { appliedIds.remove(campaign.id) }
                }
                applyError = error.localizedDescription
            }
        }
    }

    // MARK: - Sections

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.label) { item in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = item.label
                        }
                    } label: {
                        TagChip(text: item.label, filled: selectedFilter == item.label)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    /// 精选 — admin-featured brands. Hidden entirely when there are none (the Hot
    /// section + its empty state still covers the "no brands at all" case).
    @ViewBuilder
    private var featuredSection: some View {
        if !featuredBrands.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle(l10n.t(.discoverFeaturedBrands))
                brandStrip(featuredBrands)
            }
        }
    }

    /// 热门品牌 — every brand, most-applied first. This is the section that shows a
    /// friendly empty state when there are zero brands in the DB.
    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l10n.t(.discoverHotBrands))
            if hotBrands.isEmpty {
                Text(l10n.t(.discoverNoBrands))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
            } else {
                brandStrip(hotBrands)
            }
        }
    }

    private func brandStrip(_ list: [Brand]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(list) { brand in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedBrand = (selectedBrand == brand.name) ? nil : brand.name
                        }
                    } label: {
                        BrandCard(brand: brand, selected: selectedBrand == brand.name)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private var campaignsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l10n.t(.discoverOpenCampaigns))
                .padding(.horizontal, 18)
            if let selectedBrand {
                Button {
                    withAnimation { self.selectedBrand = nil }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedBrand)
                        Image(systemName: "xmark.circle.fill")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.coral.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
            }
            if visibleCampaigns.isEmpty {
                campaignsEmptyState
            } else {
                VStack(spacing: 14) {
                    ForEach(visibleCampaigns) { campaign in
                        CampaignCard(
                            campaign: campaign,
                            applied: isApplied(campaign),
                            onApply: { toggleApply(campaign) }
                        )
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var campaignsEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "megaphone")
                .font(.system(size: 40))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.discoverNoCampaigns))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 18)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.ink(for: colorScheme))
            .padding(.horizontal, 18)
    }
}

private struct BrandCard: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let brand: Brand
    var selected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiscoverIcon(iconUrl: brand.iconUrl, symbol: brand.symbol, colors: brand.colors,
                         size: 56, corner: 18, symbolSize: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(brand.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text(brand.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Text(brand.tagline)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .lineLimit(2)
                .frame(height: 32, alignment: .top)

            HStack(spacing: 5) {
                Circle().fill(Theme.coral).frame(width: 6, height: 6)
                Text("\(brand.activeCampaigns) \(l10n.t(.discoverActive))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.coral)
            }
        }
        .padding(16)
        .frame(width: 180, alignment: .leading)
        .cardStyle(cornerRadius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(selected ? Theme.coral : Color.clear, lineWidth: 2)
        )
    }
}

private struct CampaignCard: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let campaign: Campaign
    let applied: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: campaign.id) {
                HStack(spacing: 14) {
                    DiscoverIcon(iconUrl: campaign.iconUrl, symbol: campaign.symbol, colors: campaign.colors,
                                 size: 60, corner: 18, symbolSize: 24)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(campaign.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.ink(for: colorScheme))
                            .lineLimit(1)
                        Text("\(campaign.brand) · \(campaign.budget)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("\(l10n.t(.discoverDue)) \(campaign.deadline)")
                                .font(.system(size: 12, weight: .medium))
                            Text("·")
                            Text("\(campaign.spotsLeft) \(l10n.t(.discoverSpotsLeft))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(campaign.spotsLeft <= 2 ? Theme.coral : Theme.inkSecondary(for: colorScheme))
                        }
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
            }
            .buttonStyle(.plain)

            // Description (server-provided brief). Omitted when empty.
            if !campaign.description.isEmpty {
                Text(campaign.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            if !campaign.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(campaign.tags, id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    Text("\(campaign.applicationCount) \(l10n.t(.discoverApplicants))")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))

                Spacer()

                applyButton
            }
            .padding(.top, 2)
        }
        .padding(14)
        .cardStyle()
    }

    @ViewBuilder
    private var applyButton: some View {
        if applied {
            Button(action: onApply) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text(l10n.t(.discoverApplied))
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Theme.coral)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Theme.coral.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.coral, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onApply) {
                Text(l10n.t(.discoverApply))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Theme.sunset)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    DiscoverView()
}
