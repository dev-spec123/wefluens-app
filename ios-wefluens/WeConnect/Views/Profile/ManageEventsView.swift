//
//  ManageEventsView.swift
//  WeConnect
//
//  Admin event management: create/edit/delete events and PUBLISH them to the
//  Discover page, without an app update. Mirrors ManageCampaignsView, with one
//  extra concept — an event starts as a draft and only appears on Discover once
//  it's published, so drafts get their own section here. English-only (admin
//  tool). Writes go through is_admin-gated RPCs.
//

import SwiftUI
import PhotosUI

struct ManageEventsView: View {
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLoading = true
    @State private var busy = false
    @State private var editing: Event?
    @State private var creatingNew = false
    @State private var eventList: [Event] = []
    @State private var errorText: String?

    private var drafts: [Event] { eventList.filter { !$0.published } }
    private var published: [Event] { eventList.filter { $0.published } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { creatingNew = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Event").font(.system(size: 15, weight: .semibold))
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
                } else if eventList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                        Text("No events yet. Create one above — it starts as a draft, and only shows on Discover once you publish it.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    if !drafts.isEmpty {
                        group("DRAFTS (not visible on Discover)") {
                            ForEach(Array(drafts.enumerated()), id: \.element.id) { index, event in
                                eventRow(event)
                                if index < drafts.count - 1 { divider }
                            }
                        }
                    }
                    if !published.isEmpty {
                        group("PUBLISHED (live on Discover)") {
                            ForEach(Array(published.enumerated()), id: \.element.id) { index, event in
                                eventRow(event)
                                if index < published.count - 1 { divider }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle("Manage Events")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(isPresented: $creatingNew) {
            EventEditView(event: nil) { await reload() }
        }
        .sheet(item: $editing) { event in
            EventEditView(event: event) { await reload() }
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

    /// Two lines: identity + edit on top, the actions (roster / publish) below —
    /// three controls plus a title don't fit on one line at phone width.
    private func eventRow(_ event: Event) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                DiscoverIcon(
                    iconUrl: event.iconUrl, symbol: event.symbol, colors: event.colors,
                    size: 40, corner: 12, symbolSize: 16
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink(for: colorScheme)).lineLimit(1)
                    Text(eventSubtitle(event)).font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme)).lineLimit(1)
                }
                Spacer()
                Button { editing = event } label: {
                    Image(systemName: "pencil").font(.system(size: 15))
                        .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                // Roster — who signed up, not just how many.
                NavigationLink {
                    EventSignupsView(event: event)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill").font(.system(size: 11))
                        Text(signupLabel(event)).font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.coral.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Publish / unpublish — the whole point of the draft gate, one tap away.
                Button { setPublished(event, !event.published) } label: {
                    Text(event.published ? "Unpublish" : "Publish")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(event.published ? Theme.inkSecondary(for: colorScheme) : .white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(
                            event.published
                                ? AnyShapeStyle(Theme.inkTertiary(for: colorScheme).opacity(0.15))
                                : AnyShapeStyle(Theme.sunset),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
            .padding(.leading, 52)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    /// "<n> signed up", or "<n>/<capacity>" when the event is capped — the fill
    /// level is what an admin actually wants at a glance.
    private func signupLabel(_ event: Event) -> String {
        if let capacity = event.capacity {
            return "\(event.signupCount)/\(capacity) signed up"
        }
        return "\(event.signupCount) signed up"
    }

    /// "<date> · <location>" — whichever parts the event has.
    private func eventSubtitle(_ event: Event) -> String {
        var parts: [String] = [formatEventDate(event.startsAt, fallback: "No date")]
        if !event.location.isEmpty { parts.append(event.location) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    @MainActor private func reload() async {
        do { eventList = try await data.loadEventsForAdmin(); errorText = nil }
        catch { errorText = "Couldn't load events: \(error.localizedDescription)" }
        isLoading = false
    }

    private func setPublished(_ event: Event, _ publish: Bool) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await data.adminSetEventPublished(id: event.id, published: publish)
                await reload()
                // Keep the public Discover list in step so the change is visible
                // the moment the admin switches tabs.
                await data.loadDiscover()
            } catch {
                errorText = "Couldn't \(publish ? "publish" : "unpublish"): \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Event editor

struct EventEditView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let event: Event?
    let onDone: () async -> Void

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var location = ""
    @State private var tags = ""              // comma-separated
    @State private var startsAt = Date()
    @State private var endsAt = Date().addingTimeInterval(2 * 3600)
    /// Capacity is optional: off = uncapped (the app hides the spots figure).
    @State private var hasCapacity = true
    @State private var capacity = 20
    @State private var busy = false
    @State private var errorText: String?

    @State private var brands: [Brand] = []
    @State private var selectedBrandId: UUID?
    @State private var brandName = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var iconUrl: String?

    private var isEditing: Bool { event != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    iconPicker
                    field("Title", $title)
                    brandPicker
                    field("Location", $location)
                    descriptionField
                    field("Tags (comma-separated)", $tags)
                    datePicker("STARTS", $startsAt)
                    datePicker("ENDS", $endsAt)
                    capacityControls

                    if isEditing {
                        publishRow
                    } else {
                        Text("New events are saved as a draft. Publish it from the list when it's ready to go live on Discover.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                    }

                    if isEditing {
                        Button(role: .destructive) { delete() } label: {
                            Text("Delete Event").font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .foregroundStyle(.red).background(Color.red.opacity(0.1)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain).disabled(busy)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
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

    // MARK: - Publish state

    /// Saving an edit never changes the published flag (that's a separate RPC), so
    /// the editor shows the current state read-only and points at the list toggle.
    private var publishRow: some View {
        HStack(spacing: 10) {
            Image(systemName: event?.published == true ? "checkmark.seal.fill" : "pencil.and.outline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(event?.published == true ? Theme.coral : Theme.inkTertiary(for: colorScheme))
            Text(event?.published == true
                 ? "Published — live on Discover"
                 : "Draft — not visible on Discover")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Theme.card(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
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
                iconUrl: iconUrl, symbol: event?.symbol ?? "calendar",
                colors: event?.colors ?? [0xFF4D6D, 0xFF9A5A],
                size: 52, corner: 14, symbolSize: 20
            )
        }
    }

    // MARK: - Fields

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

    private func datePicker(_ label: String, _ value: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            DatePicker("", selection: value, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    private var capacityControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAPACITY").font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme)).tracking(1)
            VStack(spacing: 0) {
                Toggle(isOn: $hasCapacity) {
                    Text("Limit participants").font(.system(size: 15))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                }
                .tint(Theme.coral)
                .padding(.horizontal, 14).padding(.vertical, 10)

                if hasCapacity {
                    Divider().background(Theme.hairline(for: colorScheme))
                    Stepper(value: $capacity, in: 1...9999) {
                        Text("\(capacity) spots").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink(for: colorScheme))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
            }
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
                .autocorrectionDisabled()
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.card(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
        }
    }

    // MARK: - Load / save

    private func seed() {
        guard let event else { return }
        title = event.title
        descriptionText = event.description
        location = event.location
        tags = event.tags.joined(separator: ", ")
        selectedBrandId = event.brandId
        brandName = event.brand
        iconUrl = event.iconUrl
        if let s = event.startsAt { startsAt = s }
        if let e = event.endsAt { endsAt = e }
        if let cap = event.capacity {
            hasCapacity = true
            capacity = cap
        } else {
            hasCapacity = false
        }
    }

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
                let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedLoc = location.trimmingCharacters(in: .whitespaces)
                // 1) Upsert first so a new event has an id to attach the icon to.
                let id = try await data.adminUpsertEvent(
                    id: event?.id,
                    title: trimmedTitle,
                    description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                    location: trimmedLoc.isEmpty ? nil : trimmedLoc,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    capacity: hasCapacity ? capacity : nil,
                    tags: parsedTags(),
                    brand: brandName.isEmpty ? nil : brandName,
                    brandId: selectedBrandId,
                    symbol: event?.symbol,
                    colorA: nil,
                    colorB: nil,
                    iconUrl: iconUrl
                )
                // 2) If a new image was picked, upload it under that id and persist the URL.
                if let pickedImageData {
                    let url = try await data.uploadDiscoverIcon(kind: "events", id: id, imageData: pickedImageData)
                    try await data.adminUpsertEvent(
                        id: id,
                        title: trimmedTitle,
                        description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                        location: trimmedLoc.isEmpty ? nil : trimmedLoc,
                        startsAt: startsAt,
                        endsAt: endsAt,
                        capacity: hasCapacity ? capacity : nil,
                        tags: parsedTags(),
                        brand: brandName.isEmpty ? nil : brandName,
                        brandId: selectedBrandId,
                        symbol: event?.symbol,
                        colorA: nil,
                        colorB: nil,
                        iconUrl: url
                    )
                }
                await onDone()
                dismiss()
            } catch { errorText = "Couldn't save: \(error.localizedDescription)" }
        }
    }

    private func delete() {
        guard let event, !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do { try await data.adminDeleteEvent(id: event.id); await onDone(); dismiss() }
            catch { errorText = "Couldn't delete: \(error.localizedDescription)" }
        }
    }
}
