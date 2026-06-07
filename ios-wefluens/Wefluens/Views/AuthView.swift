//
//  AuthView.swift
//  Wefluens
//
//  Welcome / sign-in screen with email & password.
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
    @State private var passwordMismatch = false

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

            if auth.needsVerification {
                VerificationView()
                    .transition(.opacity)
            } else {
                authForm
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.needsVerification)
        .alert("Error", isPresented: $auth.showError) {
            Button("OK") {}
        } message: {
            Text(auth.errorMessage)
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

    // MARK: - Sign in / sign up form

    private var authForm: some View {
        @Bindable var auth = auth

        return VStack(spacing: 0) {
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

                Text("Wefluens")
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )

                    // Password field
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
                            .onChange(of: password) { _, _ in
                                if !confirmPassword.isEmpty {
                                    passwordMismatch = password != confirmPassword
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(passwordMismatch ? Color.red.opacity(0.6) : .white.opacity(0.18), lineWidth: 1)
                    )

                    // Confirm password (signup only)
                    if isSignUp {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.rectangle.fill")
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
                                .onChange(of: confirmPassword) { _, _ in
                                    passwordMismatch = password != confirmPassword
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(passwordMismatch ? Color.red.opacity(0.6) : .white.opacity(0.18), lineWidth: 1)
                        )

                        if passwordMismatch {
                            Text(l10n.t(.authPasswordMismatch))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .transition(.opacity)
                        }
                    }

                    // Action button
                    Button {
                        Task {
                            if isSignUp {
                                await auth.signUp(email: email.trimmingCharacters(in: .whitespaces),
                                                   password: password)
                            } else {
                                await auth.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                                   password: password)
                            }
                        }
                    } label: {
                        Group {
                            if auth.isSigningIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? l10n.t(.authSignUpButton) : l10n.t(.authSignInButton))
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

                    // Toggle sign up / sign in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSignUp.toggle()
                        }
                    } label: {
                        Text(isSignUp ? l10n.t(.authHaveAccount) : l10n.t(.authNoAccount))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
        }
    }

    private var canSubmit: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        let hasValidEmail = trimmed.contains("@") && trimmed.contains(".")
        let hasValidPassword = password.count >= 6
        let passwordsMatch = !isSignUp || password == confirmPassword
        return hasValidEmail && hasValidPassword && passwordsMatch
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
