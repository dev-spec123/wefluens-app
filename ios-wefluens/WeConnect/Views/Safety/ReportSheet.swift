//
//  ReportSheet.swift
//  WeConnect
//
//  Trust & Safety: a reusable sheet for reporting a user or a specific message.
//  Reports are written to the `reports` table for operator review (Guideline 1.2
//  — objectionable-content moderation). Optionally blocks the user in the same flow.
//

import SwiftUI

/// A reason the user can pick when filing a report. The raw value is what's stored
/// in `reports.reason`.
enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case hate
    case sexual
    case violence
    case other

    var id: String { rawValue }

    var labelKey: L10n {
        switch self {
        case .spam: return .reportReasonSpam
        case .harassment: return .reportReasonHarass
        case .hate: return .reportReasonHate
        case .sexual: return .reportReasonSexual
        case .violence: return .reportReasonViolence
        case .other: return .reportReasonOther
        }
    }

    var icon: String {
        switch self {
        case .spam: return "exclamationmark.bubble.fill"
        case .harassment: return "person.fill.xmark"
        case .hate: return "hand.raised.slash.fill"
        case .sexual: return "eye.slash.fill"
        case .violence: return "exclamationmark.triangle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

/// What's being reported. Carries everything `AppDataService.report` needs plus the
/// optional user id that can also be blocked. Identifiable so it can drive a
/// `.sheet(item:)`.
struct ReportTarget: Identifiable {
    let id: UUID
    let reportedUserId: UUID?
    let messageId: UUID?
    let messageKind: String?
    let excerpt: String?
    let subjectName: String
    /// The user that can also be blocked from this report (nil = nothing to block).
    let blockableUserId: UUID?

    /// Report a user (from a profile or a chat header).
    init(user userId: UUID, name: String) {
        self.id = userId
        self.reportedUserId = userId
        self.messageId = nil
        self.messageKind = nil
        self.excerpt = nil
        self.subjectName = name
        self.blockableUserId = userId
    }

    /// Report a specific message (`kind` is "dm" or "group").
    init(messageId: UUID, kind: String, excerpt: String?, userId: UUID?, name: String) {
        self.id = messageId
        self.reportedUserId = userId
        self.messageId = messageId
        self.messageKind = kind
        self.excerpt = excerpt
        self.subjectName = name
        self.blockableUserId = userId
    }
}

struct ReportSheet: View {
    @Environment(LocalizationManager.self) private var l10n
    @Environment(AppDataService.self) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let target: ReportTarget

    @State private var selected: ReportReason?
    @State private var alsoBlock = false
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    successState
                } else {
                    form
                }
            }
            .background(Theme.paper(for: colorScheme).ignoresSafeArea())
            .navigationTitle(l10n.t(.reportTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(submitted ? l10n.t(.settingsDone) : l10n.t(.adminCancel)) { dismiss() }
                        .foregroundStyle(Theme.coral)
                }
            }
            .alert(l10n.t(.reportError), isPresented: $showError) {
                Button(l10n.t(.authVerificationSentOk), role: .cancel) { }
            }
        }
    }

    // MARK: - Reason picker

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(l10n.t(.reportSubtitle))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(ReportReason.allCases.enumerated()), id: \.element.id) { index, reason in
                        reasonRow(reason)
                        if index < ReportReason.allCases.count - 1 {
                            Divider().background(Theme.hairline(for: colorScheme)).padding(.leading, 56)
                        }
                    }
                }
                .cardStyle()

                if target.blockableUserId != nil {
                    Toggle(isOn: $alsoBlock) {
                        Text(l10n.t(.reportAlsoBlock))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.ink(for: colorScheme))
                    }
                    .tint(Theme.coral)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .cardStyle()
                }

                submitButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    private func reasonRow(_ reason: ReportReason) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = reason }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: reason.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 30)
                Text(l10n.t(reason.labelKey))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink(for: colorScheme))
                Spacer()
                Image(systemName: selected == reason ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected == reason ? Theme.coral : Theme.inkTertiary(for: colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button(action: submit) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text(l10n.t(.reportSubmit))
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .background(selected == nil ? AnyShapeStyle(Theme.inkTertiary(for: colorScheme)) : AnyShapeStyle(Theme.sunset))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .disabled(selected == nil || isSubmitting)
        .padding(.top, 4)
    }

    // MARK: - Success

    private var successState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.coral)
            Text(l10n.t(.reportThanksTitle))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink(for: colorScheme))
            Text(l10n.t(.reportThanksMessage))
                .font(.system(size: 15))
                .foregroundStyle(Theme.inkSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Button { dismiss() } label: {
                Text(l10n.t(.settingsDone))
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .background(Theme.sunset)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
    }

    private func submit() {
        guard let reason = selected, !isSubmitting else { return }
        isSubmitting = true
        Task {
            do {
                try await data.report(
                    reportedUserId: target.reportedUserId,
                    messageId: target.messageId,
                    messageKind: target.messageKind,
                    excerpt: target.excerpt,
                    reason: reason.rawValue
                )
                if alsoBlock, let uid = target.blockableUserId {
                    try? await data.blockUser(uid)
                }
                isSubmitting = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.25)) { submitted = true }
            } catch {
                isSubmitting = false
                showError = true
                print("⚠️ report failed: \(error)")
            }
        }
    }
}
