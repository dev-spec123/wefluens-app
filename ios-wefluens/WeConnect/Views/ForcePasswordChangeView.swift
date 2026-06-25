//
//  ForcePasswordChangeView.swift
//  WeConnect
//
//  Shown full-screen right after an invited user signs in for the first time
//  with the initial password (11111111). Also reusable from Privacy & Security
//  for a voluntary password change (forced = false).
//

import SwiftUI

struct ForcePasswordChangeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    /// When true the screen is mandatory (no cancel); when false it's a normal
    /// settings sheet that can be dismissed.
    var forced: Bool = true

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var keyboardHeight: CGFloat = 0
    @State private var showSuccess = false

    private let initialPassword = "11111111"

    var body: some View {
        ZStack {
            Theme.dusk.ignoresSafeArea()

            Circle()
                .fill(Theme.sunset.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(y: keyboardHeight > 0 ? -220 : -120)
                .animation(.easeOut(duration: 0.4), value: keyboardHeight)

            VStack(spacing: 0) {
                if !forced {
                    HStack {
                        Button(l10n.t(.adminCancel)) { dismiss() }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                }

                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 92, height: 92)
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: Theme.coral.opacity(0.4), radius: 24, y: 8)

                Text(l10n.t(.forcePwTitle))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                Text(forced ? l10n.t(.forcePwSubtitle) : l10n.t(.forcePwSubtitleOptional))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 36)

                Spacer()

                VStack(spacing: 12) {
                    if !forced {
                        secureField(
                            icon: "lock.shield.fill",
                            placeholder: l10n.t(.changePwCurrent),
                            text: $currentPassword,
                            contentType: .password
                        )
                    }
                    secureField(
                        icon: "lock.fill",
                        placeholder: l10n.t(.forcePwNew),
                        text: $newPassword,
                        contentType: .newPassword
                    )
                    secureField(
                        icon: "lock.rectangle.fill",
                        placeholder: l10n.t(.forcePwConfirm),
                        text: $confirmPassword,
                        contentType: .newPassword
                    )

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Text(l10n.t(.forcePwSave))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .opacity(canSubmit ? 1 : 0.5)
                    .disabled(!canSubmit || isSaving)

                    if forced {
                        Button {
                            Task { await auth.signOut() }
                        } label: {
                            Text(l10n.t(.profileSignOut))
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
            }
        }
        .overlay(alignment: .top) {
            if showSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .animation(.easeInOut(duration: 0.2), value: errorText)
        .interactiveDismissDisabled(forced)
    }

    private func secureField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)

            SecureField("", text: text)
                .placeholder(when: text.wrappedValue.isEmpty) {
                    Text(placeholder)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .textContentType(contentType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var successToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white)
            Text(l10n.t(.changePwSuccess))
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

    private var canSubmit: Bool {
        newPassword.count >= 8 && confirmPassword.count >= 8
            && PasswordPolicy.error(newPassword) == nil
            && (forced || !currentPassword.isEmpty)
    }

    @MainActor
    private func save() async {
        errorText = nil

        // Voluntary change only: confirm the user knows their current password
        // (re-auth) before anything is changed. The forced first-login flow has
        // no current-password field and skips this entirely.
        if !forced {
            let current = currentPassword
            guard !current.isEmpty else {
                errorText = l10n.t(.changePwCurrentRequired)
                return
            }
            guard newPassword != current else {
                errorText = l10n.t(.changePwSameAsCurrent)
                return
            }
            isSaving = true
            let ok = await auth.verifyCurrentPassword(current)
            isSaving = false
            guard ok else {
                errorText = l10n.t(.changePwWrongCurrent)
                return
            }
        }

        guard newPassword.count >= 8 else {
            errorText = l10n.t(.forcePwTooShort)
            return
        }
        if let weak = PasswordPolicy.error(newPassword) {
            errorText = l10n.t(weak)
            return
        }
        guard newPassword != initialPassword else {
            errorText = l10n.t(.forcePwSameAsInitial)
            return
        }
        guard newPassword == confirmPassword else {
            errorText = l10n.t(.authPasswordMismatch)
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await auth.changePassword(to: newPassword)
            // Forced flow: mustChangePassword flips to false → ContentView swaps in
            // the main app. Optional flow: show a success toast, then dismiss the
            // sheet (mirrors RN change-password.tsx notify + router.back()).
            if !forced {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showSuccess = true
                }
                try? await Task.sleep(for: .milliseconds(1200))
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    ForcePasswordChangeView()
        .environment(AuthManager())
        .environment(LocalizationManager())
}
