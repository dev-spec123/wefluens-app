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
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: campaign.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: campaign.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
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
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let campaign: Campaign?
    let onDone: () async -> Void

    @State private var title = ""
    @State private var brand = ""
    @State private var budget = ""
    @State private var tags = ""              // comma-separated
    @State private var deadline = ""
    @State private var symbol = "sparkles"
    @State private var color1 = "FF4D6D"
    @State private var color2 = "FF9A5A"
    @State private var spotsLeft = 1
    @State private var busy = false
    @State private var errorText: String?

    private var isEditing: Bool { campaign != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Title", $title)
                    field("Brand", $brand)
                    field("Budget", $budget)
                    field("Tags (comma-separated)", $tags)
                    field("Deadline", $deadline)
                    field("SF Symbol", $symbol)
                    HStack(spacing: 12) {
                        field("Color 1 (hex)", $color1)
                        field("Color 2 (hex)", $color2)
                    }
                    spotsStepper
                    preview

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

    private var preview: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [hexColor(color1), hexColor(color2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: symbol.isEmpty ? "sparkles" : symbol)
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            Text("Preview").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.inkSecondary(for: colorScheme))
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
        brand = campaign.brand
        budget = campaign.budget
        tags = campaign.tags.joined(separator: ", ")
        deadline = campaign.deadline
        symbol = campaign.symbol
        if let c = campaign.colors.first { color1 = String(format: "%06X", c) }
        if campaign.colors.count > 1 { color2 = String(format: "%06X", campaign.colors[1]) }
        spotsLeft = campaign.spotsLeft
    }

    private func hexColor(_ s: String) -> Color {
        Color(hex: UInt(s.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) ?? 0xFF4D6D)
    }

    /// Parses a hex string into its decimal-UInt string form (e.g. "FF4D6D" → "16730477"),
    /// which is what the upsert sends as color_a / color_b (the SQL wraps them in `[a,b]`).
    private func colorValue(_ s: String, fallback: UInt) -> String {
        let v = UInt(s.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) ?? fallback
        return String(v)
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
                try await data.adminUpsertCampaign(
                    id: campaign?.id,
                    title: title.trimmingCharacters(in: .whitespaces),
                    brand: brand.isEmpty ? nil : brand,
                    budget: budget.isEmpty ? nil : budget,
                    tags: parsedTags(),
                    deadline: deadline.isEmpty ? nil : deadline,
                    symbol: symbol.isEmpty ? "sparkles" : symbol,
                    colorA: colorValue(color1, fallback: 0xFF4D6D),
                    colorB: colorValue(color2, fallback: 0xFF9A5A),
                    spotsLeft: spotsLeft
                )
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
