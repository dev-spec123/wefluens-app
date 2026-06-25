//
//  ManageCampaignsView.swift
//  WeConnect
//
//  Admin campaign management: create/edit/delete the "Open Campaigns" shown on the
//  Discover page, WITHOUT an app update. The campaign half of the admin-curated
//  Discover page (mirrors ManageBrandsView). Campaigns have no featured_rank —
//  Discover shows ALL rows from the table. English-only (admin tool). Writes go
//  through is_admin-gated RPCs.
//

import SwiftUI
import PhotosUI

struct ManageCampaignsView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLoading = true
    @State private var busy = false
    @State private var editing: Campaign? = nil
    @State private var creatingNew = false
    @State private var campaignList: [Campaign] = []
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { creatingNew = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Campaign").font(.system(size: 15, weight: .semibold))
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
                } else if campaignList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        Text("No campaigns yet. Create one above, or import the starter set.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                        Button { importSamples() } label: {
                            Text("Import sample campaigns")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.coral)
                                .padding(.horizontal, 18).padding(.vertical, 10)
                                .background(Theme.coral.opacity(0.1)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain).disabled(busy)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    group("OPEN CAMPAIGNS (shown on Discover)") {
                        ForEach(Array(campaignList.enumerated()), id: \.element.id) { index, campaign in
                            campaignRow(campaign)
                            if index < campaignList.count - 1 { divider }
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Manage Campaigns")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(isPresented: $creatingNew) {
            CampaignEditView(campaign: nil) { await reload() }
        }
        .sheet(item: $editing) { campaign in
            CampaignEditView(campaign: campaign) { await reload() }
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

    private func campaignRow(_ campaign: Campaign) -> some View {
        HStack(spacing: 12) {
            DiscoverIcon(
                iconUrl: campaign.iconUrl, symbol: campaign.symbol, colors: campaign.colors,
                size: 40, corner: 12, symbolSize: 16
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(campaign.title).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme)).lineLimit(1)
                Text(campaignSubtitle(campaign)).font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme)).lineLimit(1)
            }
            Spacer()
            Button { editing = campaign } label: {
                Image(systemName: "pencil").font(.system(size: 15)).foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    /// "<brand> · <spots> spots" — the secondary line under a campaign title.
    private func campaignSubtitle(_ campaign: Campaign) -> String {
        let brand = campaign.brand.isEmpty ? "—" : campaign.brand
        return "\(brand) · \(campaign.spotsLeft) spots"
    }

    // MARK: - Actions

    @MainActor private func reload() async {
        do { campaignList = try await data.loadCampaignsForAdmin(); errorText = nil }
        catch { errorText = "Couldn't load campaigns: \(error.localizedDescription)" }
        isLoading = false
    }

    /// Inserts the hardcoded SampleData campaigns as real DB rows (one-time seed) so
    /// there's a starter set to curate. Colors are split into the two hex values the
    /// upsert expects (as decimal-UInt strings).
    private func importSamples() {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                for c in SampleData.campaigns {
                    let a = c.colors.first ?? 0xFF4D6D
                    let b = c.colors.count > 1 ? c.colors[1] : 0xFF9A5A
                    try await data.adminUpsertCampaign(
                        id: nil, title: c.title, brand: c.brand, budget: c.budget,
                        tags: c.tags, deadline: c.deadline, symbol: c.symbol,
                        colorA: String(a), colorB: String(b), spotsLeft: c.spotsLeft)
                }
                await reload()
            } catch { errorText = "Couldn't import: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Campaign editor

struct CampaignEditView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let campaign: Campaign?
    let onDone: () async -> Void

    @State private var title = ""
    @State private var budget = ""
    @State private var tags = ""              // comma-separated
    @State private var descriptionText = ""
    @State private var deadlineDate = Date()
    @State private var spotsLeft = 1
    @State private var busy = false
    @State private var errorText: String?

    // Brand picker: loaded from loadBrandsForAdmin(). nil = "No brand" (free row).
    @State private var brands: [Brand] = []
    @State private var selectedBrandId: UUID?
    @State private var brandName = ""

    // Icon upload: the freshly picked image (preview + upload payload) and the
    // existing/uploaded public URL. No icon → the default gradient look stands in.
    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var iconUrl: String?

    /// Server stores deadline as an ISO "yyyy-MM-dd" string; this formats the picker.
    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var isEditing: Bool { campaign != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    iconPicker
                    field("Title", $title)
                    brandPicker
                    field("Budget", $budget)
                    field("Tags (comma-separated)", $tags)
                    descriptionField
                    deadlinePicker
                    spotsStepper

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    if isEditing {
                        Button(role: .destructive) { delete() } label: {
                            Text("Delete Campaign").font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .foregroundStyle(.red).background(Color.red.opacity(0.1)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain).disabled(busy)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Campaign" : "New Campaign")
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
            .task { await loadBrands() }
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let pickedImageData, let uiImage = UIImage(data: pickedImageData) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            DiscoverIcon(
                iconUrl: iconUrl, symbol: campaign?.symbol ?? "sparkles",
                colors: campaign?.colors ?? [0xFF4D6D, 0xFF9A5A],
                size: 52, corner: 14, symbolSize: 20
            )
        }
    }

    // MARK: - Brand picker

    private var brandPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.t(.adminPickBrand).uppercased()).font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            Menu {
                Button(l10n.t(.adminPickBrandNone)) {
                    selectedBrandId = nil
                    brandName = ""
                }
                ForEach(brands) { b in
                    Button(b.name) {
                        selectedBrandId = b.id
                        brandName = b.name
                    }
                }
            } label: {
                HStack {
                    Text(brandName.isEmpty ? l10n.t(.adminPickBrandNone) : brandName)
                        .font(.system(size: 16))
                        .foregroundStyle(brandName.isEmpty ? Theme.inkSecondary(for: colorScheme) : Theme.ink(for: colorScheme))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
            }
        }
    }

    // MARK: - Description

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DESCRIPTION").font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            TextField("", text: $descriptionText, axis: .vertical)
                .font(.system(size: 16)).foregroundStyle(Theme.ink(for: colorScheme))
                .lineLimit(3...8)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    // MARK: - Deadline

    private var deadlinePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.t(.adminDeadline).uppercased()).font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            DatePicker("", selection: $deadlineDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    private var spotsStepper: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SPOTS LEFT").font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            Stepper(value: $spotsLeft, in: 0...999) {
                Text("\(spotsLeft)").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink(for: colorScheme))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.card(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
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
        guard let campaign else { return }
        title = campaign.title
        budget = campaign.budget
        tags = campaign.tags.joined(separator: ", ")
        descriptionText = campaign.description
        selectedBrandId = campaign.brandId
        brandName = campaign.brand
        iconUrl = campaign.iconUrl
        spotsLeft = campaign.spotsLeft
        if let d = Self.isoDay.date(from: campaign.deadline) {
            deadlineDate = d
        }
    }

    /// Populates the brand Picker. Re-syncs the displayed brand name to the canonical
    /// row name when the seeded brandId matches a loaded brand.
    @MainActor private func loadBrands() async {
        do {
            brands = try await data.loadBrandsForAdmin()
            if let id = selectedBrandId, let match = brands.first(where: { $0.id == id }) {
                brandName = match.name
            }
        } catch {
            // Non-fatal: the picker just shows "No brand" / the seeded name.
        }
    }

    /// Splits the comma-separated tags field into a trimmed, non-empty array.
    private func parsedTags() -> [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() {
        guard canSave else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
                let deadlineISO = Self.isoDay.string(from: deadlineDate)
                let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                // 1) Upsert first so a new campaign has an id to attach the icon to.
                //    Symbol/colors keep their server defaults (admin no longer edits them).
                let id = try await data.adminUpsertCampaign(
                    id: campaign?.id,
                    title: trimmedTitle,
                    brand: brandName.isEmpty ? nil : brandName,
                    budget: budget.isEmpty ? nil : budget,
                    tags: parsedTags(),
                    deadline: deadlineISO,
                    symbol: campaign?.symbol,
                    colorA: nil,
                    colorB: nil,
                    spotsLeft: spotsLeft,
                    iconUrl: iconUrl,
                    description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                    brandId: selectedBrandId
                )
                // 2) If a new image was picked, upload it under that id and persist the URL.
                if let pickedImageData {
                    let url = try await data.uploadDiscoverIcon(kind: "campaigns", id: id, imageData: pickedImageData)
                    try await data.adminUpsertCampaign(
                        id: id,
                        title: trimmedTitle,
                        brand: brandName.isEmpty ? nil : brandName,
                        budget: budget.isEmpty ? nil : budget,
                        tags: parsedTags(),
                        deadline: deadlineISO,
                        symbol: campaign?.symbol,
                        colorA: nil,
                        colorB: nil,
                        spotsLeft: spotsLeft,
                        iconUrl: url,
                        description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                        brandId: selectedBrandId
                    )
                }
                await onDone()
                dismiss()
            } catch { errorText = "Couldn't save: \(error.localizedDescription)" }
        }
    }

    private func delete() {
        guard let campaign, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await data.adminDeleteCampaign(id: campaign.id); await onDone(); dismiss() }
            catch { errorText = "Couldn't delete: \(error.localizedDescription)" }
        }
    }
}
