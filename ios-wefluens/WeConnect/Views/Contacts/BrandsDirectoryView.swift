//
//  BrandsDirectoryView.swift
//  WeConnect
//
//  The "Brands" directory — pushed from the Contacts tab. Lists the brands from
//  the `brands` table (the same data Discover uses) and drills into a brand's
//  open campaigns, reusing CampaignDetailView. Distinct from Discover, which is
//  campaign-first; this is brand-first.
//

import SwiftUI

struct BrandsDirectoryView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    private var brands: [Brand] { data.brands }

    /// Distinct, non-empty brand categories (A–Z) for the filter chips.
    private var categories: [String] {
        Array(Set(brands.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    /// Brands after applying the category chip and the search text (name,
    /// category, or tagline).
    private var filteredBrands: [Brand] {
        var list = brands
        if let selectedCategory {
            list = list.filter { $0.category == selectedCategory }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed) ||
                $0.category.localizedCaseInsensitiveContains(trimmed) ||
                $0.tagline.localizedCaseInsensitiveContains(trimmed)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            Theme.paper(for: colorScheme).ignoresSafeArea()

            if isLoading && brands.isEmpty {
                ProgressView().tint(Theme.coral).scaleEffect(1.1)
            } else if brands.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        searchBar
                        if !categories.isEmpty { categoryBar }
                        if filteredBrands.isEmpty {
                            noMatchesState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(filteredBrands) { brand in
                                    NavigationLink {
                                        BrandCampaignsView(brand: brand)
                                    } label: {
                                        BrandDirectoryRow(brand: brand, campaignCount: campaignCount(for: brand))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(l10n.t(.contactsBrands))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if brands.isEmpty { await data.loadDiscover() }
            isLoading = false
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            TextField(l10n.t(.brandsSearch), text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink(for: colorScheme))
                .autocorrectionDisabled()
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

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: l10n.t(.filterAll), isOn: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { category in
                    chip(title: category, isOn: selectedCategory == category) {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        } label: {
            TagChip(text: title, filled: isOn)
        }
        .buttonStyle(.plain)
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
            Text(l10n.t(.brandsNoMatches))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
        }
        .padding(.top, 40)
    }

    private func campaignCount(for brand: Brand) -> Int {
        data.campaigns.filter { $0.brand == brand.name }.count
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.coral.opacity(0.85))
                .frame(width: 76, height: 76)
                .background(Theme.coral.opacity(0.1))
                .clipShape(Circle())
            Text(l10n.t(.brandsEmpty))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Brand row

private struct BrandDirectoryRow: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let brand: Brand
    let campaignCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: brand.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: brand.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(brand.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text(brand.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle().fill(Theme.coral).frame(width: 6, height: 6)
                Text("\(campaignCount) \(l10n.t(.discoverActive))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.coral)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - One brand's campaigns

private struct BrandCampaignsView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let brand: Brand

    private var campaigns: [Campaign] {
        data.campaigns.filter { $0.brand == brand.name }
    }

    var body: some View {
        ZStack {
            Theme.paper(for: colorScheme).ignoresSafeArea()
            if campaigns.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    Text(l10n.t(.brandsNoCampaigns))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(campaigns) { campaign in
                            NavigationLink {
                                CampaignDetailView(campaign: campaign)
                            } label: {
                                BrandCampaignRow(campaign: campaign)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(brand.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BrandCampaignRow: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    let campaign: Campaign

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: campaign.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: campaign.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(campaign.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(1)
                Text(campaign.budget)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
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
