//
//  SupportContactView.swift
//  WeConnect
//
//  In-app "Contact Support" form. Records a ticket in support_tickets and emails
//  the support inbox via Resend (submit-support-ticket edge function). Replaces
//  the old mailto: composer.
//

import SwiftUI

struct SupportContactView: View {
    @Environment(AppDataService.self) private var data
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var errorText: String?

    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
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
                    body: message.trimmingCharacters(in: .whitespacesAndNewlines)
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
