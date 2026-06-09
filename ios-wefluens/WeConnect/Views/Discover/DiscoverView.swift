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

    @State private var selectedFilter: String = "All"

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
        campaigns
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

                    featured
                    filterBar
                    brandsSection
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
        }
    }

    private var featured: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.dusk
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 200, height: 200)
                .offset(x: 120, y: -60)
                .blur(radius: 8)

            VStack(alignment: .leading, spacing: 12) {
                TagChip(text: l10n.t(.discoverFeatured), filled: false)
                    .colorScheme(.dark)
                Text("Glossier Summer\nGlow Launch")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("3 creator spots · $8K–12K budget")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Button {
                } label: {
                    Text(l10n.t(.discoverViewBrief))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.plum)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Theme.plum.opacity(0.3), radius: 20, y: 12)
        .padding(.horizontal, 18)
    }

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

    private var brandsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l10n.t(.discoverTopBrands))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(brands) { brand in
                        BrandCard(brand: brand)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var campaignsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(l10n.t(.discoverOpenCampaigns))
                .padding(.horizontal, 18)
            VStack(spacing: 14) {
                ForEach(visibleCampaigns) { campaign in
                    NavigationLink(value: campaign.id) {
                        CampaignCard(campaign: campaign)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: brand.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: brand.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(brand.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Text(brand.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
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
    }
}

private struct CampaignCard: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let campaign: Campaign

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: campaign.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: campaign.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)

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
        .padding(14)
        .cardStyle()
    }
}

#Preview {
    DiscoverView()
}
