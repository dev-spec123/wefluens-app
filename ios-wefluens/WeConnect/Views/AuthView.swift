//
//  AuthView.swift
//  WeConnect
//
//  Invite-only sign-in screen. Accounts are created by an admin invite, so there
//  is no public sign-up — just email + password.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showResetSent = false

    // Inline per-field validation errors.
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmError: String?

    private static let minPasswordLength = 8

    var body: some View {
        @Bindable var auth = auth

        ZStack {
            Theme.dusk
                .ignoresSafeArea()

            Circle()
                .fill(Theme.sunset.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(y: keyboardHeight > 0 ? -200 : -60)
                .animation(.easeOut(duration: 0.4), value: keyboardHeight)

            if auth.signUpNeedsConfirmation {
                checkEmailView
                    .transition(.opacity)
            } else {
                authForm
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.signUpNeedsConfirmation)
        .alert("Error", isPresented: $auth.showError) {
            Button("OK") {}
        } message: {
            Text(auth.errorMessage)
        }
        .alert(l10n.t(.authResetSentTitle), isPresented: $showResetSent) {
            Button(l10n.t(.authVerificationSentOk)) {}
        } message: {
            Text(l10n.t(.authResetSentMessage))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    // MARK: - Sign in form

    private var authForm: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 84, height: 84)

                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.coral.opacity(0.4), radius: 24, y: 8)

            Text("WeConnect")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 20)

            Text(l10n.t(.authTagline))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)

            Spacer()

            // Form
            VStack(spacing: 12) {
                // Email field
                fieldContainer(error: emailError) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)

                        TextField("", text: $email)
                            .placeholder(when: email.isEmpty) {
                                Text(l10n.t(.authEmailPlaceholder))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: email) { _, _ in emailError = nil }
                    }
                }

                // Password field
                fieldContainer(error: passwordError) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)

                        SecureField("", text: $password)
                            .placeholder(when: password.isEmpty) {
                                Text(l10n.t(.authPasswordPlaceholder))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .onChange(of: password) { _, _ in passwordError = nil }
                            .onSubmit { submit() }
                    }
                }

                // Confirm password (sign-up only)
                if isSignUp {
                    fieldContainer(error: confirmError) {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 20)

                            SecureField("", text: $confirmPassword)
                                .placeholder(when: confirmPassword.isEmpty) {
                                    Text(l10n.t(.authConfirmPasswordPlaceholder))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .textContentType(.newPassword)
                                .onChange(of: confirmPassword) { _, _ in confirmError = nil }
                                .onSubmit { submit() }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Sign in / Create account button
                Button {
                    submit()
                } label: {
                    Group {
                        if auth.isSigningIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(l10n.t(isSignUp ? .authSignUpButton : .authSignInButton))
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                }
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(auth.isSigningIn || !canSubmit)

                // Forgot password (sign-in only)
                if !isSignUp {
                    Button {
                        sendReset()
                    } label: {
                        Text(l10n.t(.authForgotPassword))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 4)
                }

                // Toggle sign in / sign up
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSignUp.toggle()
                        confirmPassword = ""
                        emailError = nil
                        passwordError = nil
                        confirmError = nil
                    }
                } label: {
                    Text(l10n.t(isSignUp ? .authHaveAccount : .authNoAccount))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if isSignUp {
            guard validateSignUp(trimmedEmail) else { return }
            Task { await auth.signUp(email: trimmedEmail, password: password) }
        } else {
            guard isValidEmail(trimmedEmail) else {
                emailError = l10n.t(.authErrInvalidEmail)
                return
            }
            guard !password.isEmpty else {
                passwordError = l10n.t(.authErrPasswordRequired)
                return
            }
            Task { await auth.signIn(email: trimmedEmail, password: password) }
        }
    }

    /// Validates the sign-up fields, populating inline errors. Returns true when clean.
    private func validateSignUp(_ trimmedEmail: String) -> Bool {
        emailError = nil
        passwordError = nil
        confirmError = nil

        var ok = true
        if !isValidEmail(trimmedEmail) {
            emailError = l10n.t(.authErrInvalidEmail)
            ok = false
        }
        if password.count < Self.minPasswordLength {
            passwordError = l10n.t(.authErrPasswordShort)
            ok = false
        }
        if confirmPassword != password {
            confirmError = l10n.t(.authPasswordMismatch)
            ok = false
        }
        return ok
    }

    private func sendReset() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard isValidEmail(trimmed) else {
            emailError = l10n.t(.authErrInvalidEmail)
            return
        }
        Task {
            do {
                try await auth.sendPasswordReset(email: trimmed)
                showResetSent = true
            } catch {
                auth.errorMessage = error.localizedDescription
                auth.showError = true
            }
        }
    }

    /// Lightweight RFC-ish email check: non-empty local part, an @, and a dotted domain.
    private func isValidEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    private var canSubmit: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
        }
        return !email.isEmpty && !password.isEmpty
    }

    // MARK: - Field container with inline error

    @ViewBuilder
    private func fieldContainer<Content: View>(
        error: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(error == nil ? .white.opacity(0.18) : Theme.coral, lineWidth: 1)
                )

            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.coral)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    // MARK: - Check-your-email screen

    private var checkEmailView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.coral.opacity(0.4), radius: 24, y: 8)

            Text(l10n.t(.authCheckEmailTitle))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 24)

            Text(l10n.t(.authCheckEmailMessage))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 36)

            if !auth.pendingConfirmationEmail.isEmpty {
                Text(auth.pendingConfirmationEmail)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
            }

            Spacer()

            Button {
                auth.cancelSignUpConfirmation()
                password = ""
                confirmPassword = ""
                isSignUp = false
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
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Placeholder modifier

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthManager())
        .environment(LocalizationManager())
}
