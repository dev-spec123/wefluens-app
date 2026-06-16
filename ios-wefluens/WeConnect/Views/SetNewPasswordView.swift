//
//  SetNewPasswordView.swift
//  WeConnect
//
//  Shown full-screen after the user opens a password-reset deep link
//  (wefluens://reset-password). Reuses the sign-up password validation
//  (>= 8 chars + match) and calls Supabase Auth updateUser via
//  AuthManager.updateRecoveredPassword.
//

import SwiftUI

struct SetNewPasswordView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var didSucceed = false
    @State private var keyboardHeight: CGFloat = 0

    private static let minPasswordLength = 8

    var body: some View {
        ZStack {
            Theme.dusk.ignoresSafeArea()

            Circle()
                .fill(Theme.sunset.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(y: keyboardHeight > 0 ? -220 : -120)
                .animation(.easeOut(duration: 0.4), value: keyboardHeight)

            if didSucceed {
                successView
            } else {
                formView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: didSucceed)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .interactiveDismissDisabled(true)
    }

    private var formView: some View {
        VStack(spacing: 0) {
            Spacer()

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

            Text(l10n.t(.forcePwSubtitleOptional))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 12) {
                secureField(icon: "lock.fill", placeholder: l10n.t(.forcePwNew), text: $newPassword)
                secureField(icon: "lock.rectangle.fill", placeholder: l10n.t(.forcePwConfirm), text: $confirmPassword)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.coral)
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
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 44)
        }
        .animation(.easeInOut(duration: 0.2), value: errorText)
    }

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 92, height: 92)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.coral.opacity(0.4), radius: 24, y: 8)

            Text(l10n.t(.setPwSuccess))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
                .padding(.horizontal, 36)

            Spacer()

            Button {
                auth.passwordRecoveryActive = false
            } label: {
                Text(l10n.t(.authBackToSignIn))
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .background(.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)
            .padding(.bottom, 44)
        }
    }

    private func secureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
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
                .textContentType(.newPassword)
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

    private var canSubmit: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty
    }

    @MainActor
    private func save() async {
        errorText = nil

        guard newPassword.count >= Self.minPasswordLength else {
            errorText = l10n.t(.forcePwTooShort)
            return
        }
        guard newPassword == confirmPassword else {
            errorText = l10n.t(.authPasswordMismatch)
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await auth.updateRecoveredPassword(to: newPassword)
            didSucceed = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    SetNewPasswordView()
        .environment(AuthManager())
        .environment(LocalizationManager())
}
