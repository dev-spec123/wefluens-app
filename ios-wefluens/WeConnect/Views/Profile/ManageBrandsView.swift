//
//  ManageBrandsView.swift
//  WeConnect
//
//  Admin brand management + curation: create/edit/delete brands, and feature/order
//  them for Discover's Top Brands strip. English-only (admin tool). Writes go
//  through is_admin-gated RPCs.
//

import SwiftUI
import PhotosUI

struct ManageBrandsView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLoading = true
    @State private var busy = false
    @State private var editing: Brand? = nil
    @State private var creatingNew = false
    @State private var brandList: [Brand] = []
    @State private var errorText: String?

    private var brands: [Brand] { brandList }
    private var featured: [Brand] {
        brands.filter { $0.featuredRank != nil }
            .sorted { ($0.featuredRank ?? 0) < ($1.featuredRank ?? 0) }
    }
    private var others: [Brand] {
        brands.filter { $0.featuredRank == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { creatingNew = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Brand").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.sunset).clipShape(Capsule())
                }
                .buttonStyle(.plain)

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
                    ProgressView().tint(Theme.coral).frame(maxWidth: .infinity).padding(.vertical, 20)
                } else if brandList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        Text("No brands yet. Create one above, or import the starter set.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                        Button { importSamples() } label: {
                            Text("Import sample brands")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.coral)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Theme.coral.opacity(0.1)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain).disabled(busy)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    if !featured.isEmpty {
                        group("FEATURED (Top Brands, in order)") {
                            ForEach(Array(featured.enumerated()), id: \.element.id) { index, brand in
                                brandRow(brand, featuredIndex: index)
                                if index < featured.count - 1 { divider }
                            }
                        }
                    }
                    group(others.isEmpty ? "ALL BRANDS" : "ALL BRANDS") {
                        if others.isEmpty {
                            Text("No other brands.").font(.system(size: 14))
                                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                        } else {
                            ForEach(Array(others.enumerated()), id: \.element.id) { index, brand in
                                brandRow(brand, featuredIndex: nil)
                                if index < others.count - 1 { divider }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Manage Brands")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(isPresented: $creatingNew) {
            BrandEditView(brand: nil) { await reload() }
        }
        .sheet(item: $editing) { brand in
            BrandEditView(brand: brand) { await reload() }
        }
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

    private func brandRow(_ brand: Brand, featuredIndex: Int?) -> some View {
        HStack(spacing: 12) {
            DiscoverIcon(
                iconUrl: brand.iconUrl, symbol: brand.symbol, colors: brand.colors,
                size: 40, corner: 12, symbolSize: 16
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(brand.name).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme)).lineLimit(1)
                Text(brand.category).font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme)).lineLimit(1)
            }
            Spacer()
            if let featuredIndex {
                Button { move(brand, by: -1) } label: { arrow("chevron.up") }
                    .disabled(featuredIndex == 0 || busy)
                Button { move(brand, by: 1) } label: { arrow("chevron.down") }
                    .disabled(featuredIndex == featured.count - 1 || busy)
                Button { setFeatured(brand, rank: nil) } label: {
                    Image(systemName: "star.slash.fill").font(.system(size: 15)).foregroundStyle(Theme.coral)
                }.disabled(busy)
            } else {
                Button { setFeatured(brand, rank: (featured.map { $0.featuredRank ?? 0 }.max() ?? 0) + 1) } label: {
                    Image(systemName: "star.fill").font(.system(size: 15)).foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }.disabled(busy)
            }
            Button { editing = brand } label: {
                Image(systemName: "pencil").font(.system(size: 15)).foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func arrow(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            .frame(width: 30, height: 30).background(Theme.cardSubtle(for: colorScheme)).clipShape(Circle())
    }

    // MARK: - Actions

    @MainActor private func reload() async {
        do { brandList = try await data.loadBrandsForAdmin(); errorText = nil }
        catch { errorText = "Couldn't load brands: \(error.localizedDescription)" }
        isLoading = false
    }

    private func setFeatured(_ brand: Brand, rank: Int?) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await data.adminSetFeaturedBrand(brandId: brand.id, rank: rank); await reload() }
            catch { errorText = "Couldn't update brand: \(error.localizedDescription)" }
        }
    }

    /// Inserts the hardcoded SampleData brands as real DB rows (one-time seed) so
    /// there's a starter set to curate. Colors are stored as the JSON [UInt] format
    /// parseColors expects.
    private func importSamples() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                for b in SampleData.brands {
                    let colorsJSON = "[\(b.colors.map(String.init).joined(separator: ","))]"
                    try await data.adminUpsertBrand(
                        id: nil, name: b.name, category: b.category, tagline: b.tagline,
                        symbol: b.symbol, colors: colorsJSON, activeCampaigns: b.activeCampaigns, featuredRank: nil)
                }
                await reload()
            } catch { errorText = "Couldn't import: \(error.localizedDescription)" }
        }
    }

    private func move(_ brand: Brand, by delta: Int) {
        guard let i = featured.firstIndex(where: { $0.id == brand.id }) else { return }
        let target = i + delta
        guard !busy, featured.indices.contains(target) else { return }
        busy = true
        let a = featured[i], b = featured[target]
        Task {
            defer { busy = false }
            do {
                try await data.adminSetFeaturedBrand(brandId: a.id, rank: b.featuredRank)
                try await data.adminSetFeaturedBrand(brandId: b.id, rank: a.featuredRank)
                await reload()
            } catch { errorText = "Couldn't reorder: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Brand editor

struct BrandEditView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let brand: Brand?
    let onDone: () async -> Void

    @State private var name = ""
    @State private var category = ""
    @State private var tagline = ""
    @State private var busy = false
    @State private var errorText: String?

    // Icon upload: the freshly picked image (preview + upload payload) and the
    // existing/uploaded public URL. No icon → the default gradient look stands in.
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var iconUrl: String?

    private var isEditing: Bool { brand != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    iconPicker
                    field("Name", $name)
                    field("Category", $category)
                    field("Tagline", $tagline)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    if isEditing {
                        Button(role: .destructive) { delete() } label: {
                            Text("Delete Brand").font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .foregroundStyle(.red).background(Color.red.opacity(0.1)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain).disabled(busy)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Brand" : "New Brand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.foregroundStyle(Theme.coral).disabled(!canSave)
                }
            }
            .onAppear(perform: seed)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let imgData = try? await newItem.loadTransferable(type: Data.self) {
                        pickedImageData = imgData
                    }
                }
            }
        }
    }

    // MARK: - Icon picker

    private var iconPicker: some View {
        HStack(spacing: 14) {
            iconPreview
            VStack(alignment: .leading, spacing: 8) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text(l10n.t(.adminUploadIcon)).font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Theme.coral.opacity(0.1)).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The picked image (if any) takes precedence; then the existing uploaded URL;
    /// otherwise the default gradient look via the shared DiscoverIcon fallback.
    @ViewBuilder
    private var iconPreview: some View {
        if let pickedImageData, let uiImage = UIImage(data: pickedImageData) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            DiscoverIcon(
                iconUrl: iconUrl, symbol: brand?.symbol ?? "sparkles",
                colors: brand?.colors ?? [0xFF4D6D, 0xFF9A5A],
                size: 52, corner: 14, symbolSize: 20
            )
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            TextField("", text: text)
                .font(.system(size: 16)).foregroundStyle(Theme.ink(for: colorScheme))
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    private func seed() {
        guard let brand else { return }
        name = brand.name
        category = brand.category
        tagline = brand.tagline
        iconUrl = brand.iconUrl
    }

    private func save() {
        guard canSave else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                // 1) Upsert first so a new brand has an id to attach the icon to.
                //    Symbol/colors keep their server defaults (admin no longer edits them).
                let id = try await data.adminUpsertBrand(
                    id: brand?.id,
                    name: trimmedName,
                    category: category.isEmpty ? nil : category,
                    tagline: tagline.isEmpty ? nil : tagline,
                    symbol: brand?.symbol,
                    colors: nil,
                    activeCampaigns: brand?.activeCampaigns,
                    featuredRank: brand?.featuredRank,
                    iconUrl: iconUrl
                )
                // 2) If a new image was picked, upload it under that id and persist the URL.
                if let pickedImageData {
                    let url = try await data.uploadDiscoverIcon(kind: "brands", id: id, imageData: pickedImageData)
                    try await data.adminUpsertBrand(
                        id: id,
                        name: trimmedName,
                        category: category.isEmpty ? nil : category,
                        tagline: tagline.isEmpty ? nil : tagline,
                        symbol: brand?.symbol,
                        colors: nil,
                        activeCampaigns: brand?.activeCampaigns,
                        featuredRank: brand?.featuredRank,
                        iconUrl: url
                    )
                }
                await onDone()
                dismiss()
            } catch { errorText = "Couldn't save: \(error.localizedDescription)" }
        }
    }

    private func delete() {
        guard let brand, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await data.adminDeleteBrand(id: brand.id); await onDone(); dismiss() }
            catch { errorText = "Couldn't delete: \(error.localizedDescription)" }
        }
    }
}
