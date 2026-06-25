//
//  SupportContactView.swift
//  WeConnect
//
//  In-app "Contact Support" form. Records a ticket in support_tickets and emails
//  the support inbox via Resend (submit-support-ticket edge function). Replaces
//  the old mailto: composer.
//

import SwiftUI
import PhotosUI

struct SupportContactView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// Feedback categories sent to the edge function as `type`.
    private enum FeedbackType: String, CaseIterable {
        case bug, idea, other
    }

    /// Per-image size cap enforced before/after compression: 5 MB.
    private static let maxImageBytes = 5 * 1024 * 1024
    /// Max number of attachments accepted by the edge function.
    private static let maxImages = 6

    @State private var subject = ""
    @State private var message = ""
    @State private var feedbackType: FeedbackType = .other
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @State private var isSending = false
    @State private var sent = false
    @State private var errorText: String?

    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
    }

    private func typeLabel(_ type: FeedbackType) -> String {
        switch type {
        case .bug: return l10n.t(.supportTypeBug)
        case .idea: return l10n.t(.supportTypeIdea)
        case .other: return l10n.t(.supportTypeOther)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper(for: colorScheme).ignoresSafeArea()

                if sent {
                    sentState
                } else {
                    form
                }
            }
            .navigationTitle(l10n.t(.supportFormTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(l10n.t(.settingsDone)) { dismiss() }
                        .foregroundStyle(Theme.coral)
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(l10n.t(.supportIntro))
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                field(title: l10n.t(.supportTypeField)) {
                    Picker(l10n.t(.supportTypeField), selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Text(typeLabel(type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                field(title: l10n.t(.supportSubjectField)) {
                    TextField(l10n.t(.supportSubjectPlaceholder), text: $subject)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Theme.card(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                }

                field(title: l10n.t(.supportMessageField)) {
                    TextEditor(text: $message)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink(for: colorScheme))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160, alignment: .topLeading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Theme.card(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                        .overlay(alignment: .topLeading) {
                            if message.isEmpty {
                                Text(l10n.t(.supportMessagePlaceholder))
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                imagesField

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }

                Button { send() } label: {
                    HStack(spacing: 8) {
                        if isSending { ProgressView().tint(.white) }
                        Text(l10n.t(.supportSendButton))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.sunset)
                    .clipShape(Capsule())
                    .shadow(color: Theme.coral.opacity(0.3), radius: 12, y: 6)
                    .opacity(canSend ? 1 : 0.55)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
        }
    }

    private var sentState: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color(hex: 0x2AD17E))
            Text(l10n.t(.supportSentMsg))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
                .tracking(1)
            content()
        }
    }

    private var imagesField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: Self.maxImages,
                    matching: .images
                ) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20, weight: .semibold))
                        Text(l10n.t(.supportAddImages))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.coral)
                    .frame(width: 78, height: 78)
                    .background(Theme.card(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))
                }
                .disabled(images.count >= Self.maxImages)
                .opacity(images.count >= Self.maxImages ? 0.5 : 1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                            thumbnail(for: data, at: index)
                        }
                    }
                }
            }

            Text(l10n.t(.supportMaxImages))
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkTertiary(for: colorScheme))
        }
        .onChange(of: pickerItems) { _, items in
            loadImages(from: items)
        }
    }

    @ViewBuilder
    private func thumbnail(for data: Data, at index: Int) -> some View {
        if let uiImage = UIImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline(for: colorScheme), lineWidth: 1))

                Button {
                    images.remove(at: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
    }

    /// Loads each picked item as Data, rejecting any over 5 MB and capping the
    /// total at 6. Clears the picker selection afterward so the same photo can
    /// be re-added and selection state stays in sync with `images`.
    private func loadImages(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var collected = images
            var rejectedTooLarge = false
            for item in items {
                if collected.count >= Self.maxImages { break }
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                if data.count > Self.maxImageBytes {
                    rejectedTooLarge = true
                    continue
                }
                collected.append(data)
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    images = Array(collected.prefix(Self.maxImages))
                }
                errorText = rejectedTooLarge ? l10n.t(.supportImageTooLarge) : nil
                pickerItems = []
            }
        }
    }

    private func send() {
        guard canSend else {
            errorText = l10n.t(.supportEmptyMsg)
            return
        }
        isSending = true
        errorText = nil
        Task {
            defer { isSending = false }
            do {
                let ok = try await data.submitSupportTicket(
                    subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: message.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: feedbackType.rawValue,
                    language: l10n.language,
                    images: images
                )
                if ok {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { sent = true }
                } else {
                    errorText = l10n.t(.supportErrorMsg)
                }
            } catch {
                print("⚠️ submit support ticket failed: \(error)")
                errorText = l10n.t(.supportErrorMsg)
            }
        }
    }
}
