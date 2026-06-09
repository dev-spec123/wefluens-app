//
//  EditProfileView.swift
//  WeConnect
//
//  Robust profile editor that always saves correctly.
//  Uses per-field @State with original-value tracking so the save
//  button works even before the cloud profile finishes loading.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // --- original values (snapshot from cloud on appear) ---
    @State private var originalName: String = ""
    @State private var originalBio: String = ""
    @State private var originalLocation: String = ""

    // --- editable fields ---
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var handle: String = ""

    // --- save state ---
    @State private var showSuccess: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var isInitialLoadDone: Bool = false

    // --- avatar ---
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImageData: Data?
    @State private var photoHasChanged: Bool = false

    // --- location ---
    private let locationService = LocationService()
    @State private var locationStatus: LocationStatus = .idle

    // MARK: - Derived

    private var hasChanges: Bool {
        name != originalName || bio != originalBio || location != originalLocation || photoHasChanged
    }

    private var displayInitials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? parts.last?.first.map(String.init) ?? "" : ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                avatarSection
                formSection
                saveButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Theme.paper(for: colorScheme).ignoresSafeArea())
        .navigationTitle(l10n.t(.editProfileTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
            }
        }
        .overlay(alignment: .top) {
            if showSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            // Wait for cloud profile to load, then snapshot field values.
            // This runs once when the view appears.
            if !isInitialLoadDone {
                // Give a moment for the environment to propagate the real dataService
                try? await Task.sleep(for: .milliseconds(200))
                await data.refreshProfile()
                snapshotOriginals()
                isInitialLoadDone = true
            }
        }
        .onChange(of: locationStatus) { _, status in
            if case .resolved(let text) = status {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    location = text
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { locationStatus = .idle }
                }
            }
            if case .denied = status {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation { locationStatus = .idle }
                }
            }
        }
        .alert("Save Failed", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Snapshot originals from cloud (or fallback)

    private func snapshotOriginals() {
        if let p = data.profile {
            name = p.name
            bio = p.bio
            location = p.location
            handle = p.handle
        } else {
            // No cloud profile yet — use safe fallbacks
            name = ""
            bio = ""
            location = ""
            handle = ""
        }
        originalName = name
        originalBio = bio
        originalLocation = location
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                avatarContent
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 8)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.sunset)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.paper(for: colorScheme), lineWidth: 3))
                }
                .offset(x: 4, y: 4)
            }

            Text(l10n.t(.editProfileChangePhoto))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.coral)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let imgData = try? await newItem.loadTransferable(type: Data.self) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        profileImageData = imgData
                        photoHasChanged = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let imgData = profileImageData, let uiImage = UIImage(data: imgData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        else if let urlStr = data.profile?.avatarUrl, !urlStr.isEmpty,
                let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                case .failure, .empty:
                    gradientAvatar
                @unknown default:
                    gradientAvatar
                }
            }
        }
        else {
            gradientAvatar
        }
    }

    private var gradientAvatar: some View {
        Avatar(
            colors: [0xFF4D6D, 0xFF9A5A],
            initials: displayInitials,
            size: 100,
            isOnline: true
        )
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 4) {
            formField(icon: "person.fill", title: l10n.t(.editProfileName), text: $name)
            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 56)

            formField(icon: "at", title: "Handle", text: $handle)
                .disabled(true)
            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 56)

            formField(icon: "text.alignleft", title: l10n.t(.editProfileBio), text: $bio, axis: .vertical, lineLimit: 2...5)
            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 56)

            locationField
        }
        .padding(.vertical, 8)
        .cardStyle()
    }

    private func formField(
        icon: String,
        title: String,
        text: Binding<String>,
        axis: Axis = .horizontal,
        lineLimit: ClosedRange<Int> = 1...1
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    .tracking(0.8)

                TextField(title, text: text, axis: axis)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                    .lineLimit(lineLimit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Location

    private var locationField: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.coral)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.editProfileLocation).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                    .tracking(0.8)

                HStack(spacing: 8) {
                    TextField(l10n.t(.editProfileLocationPlaceholder), text: $location)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .disabled(locationStatus == .locating)
                    locateButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private var locateButton: some View {
        switch locationStatus {
        case .idle:
            Button {
                locationService.requestLocation { status in
                    locationStatus = status
                }
            } label: {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.coral)
            }
            .buttonStyle(.plain)

        case .locating:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
                .tint(Theme.coral)

        case .resolved:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: 0x2AD17E))

        case .denied:
            Image(systemName: "location.slash.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))

        case .unavailable:
            Image(systemName: "location.slash")
                .font(.system(size: 18))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: 0xFF9500))
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task { await performSave() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                }
                Text(l10n.t(.editProfileSave))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                hasChanges && !isSaving
                    ? AnyShapeStyle(Theme.sunset)
                    : AnyShapeStyle(Theme.inkTertiary(for: colorScheme))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: hasChanges && !isSaving ? Theme.coral.opacity(0.35) : .clear,
                radius: 14, y: 8
            )
        }
        .disabled(!hasChanges || isSaving)
        .animation(.easeInOut(duration: 0.25), value: hasChanges)
    }

    @MainActor
    private func performSave() async {
        guard let uid = data.userId else {
            saveError = l10n.t(.editProfileSave) + " failed: Not signed in."
            return
        }
        isSaving = true
        defer { isSaving = false }

        var avatarUrl: String? = data.profile?.avatarUrl

        // Step 1: Upload the new avatar. If it fails, surface a REAL error and stop —
        // never silently keep the old avatar and pretend the save succeeded.
        if photoHasChanged, let imageData = profileImageData {
            do {
                avatarUrl = try await data.uploadAvatar(userId: uid, imageData: imageData)
            } catch {
                saveError = error.localizedDescription
                return
            }
        }

        // Step 2: Persist profile fields
        do {
            try await data.updateProfile(
                name: name,
                bio: bio,
                location: location,
                avatarUrl: avatarUrl
            )
        } catch {
            saveError = error.localizedDescription
            return
        }

        // Step 3: Re-fetch from cloud so ProfileView sees the latest data
        await data.refreshProfile()

        // Step 4: Update originals so the button correctly disables again
        originalName = name
        originalBio = bio
        originalLocation = location
        photoHasChanged = false

        // Step 5: Show success + dismiss
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { showSuccess = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            dismiss()
        }
    }

    // MARK: - Toast

    private var successToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
            Text("Profile updated!")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: 0x2AD17E))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .padding(.top, 60)
    }
}

#Preview {
    NavigationStack {
        EditProfileView()
            .environment(LocalizationManager())
            .environment(AppDataService(userId: nil))
    }
}
