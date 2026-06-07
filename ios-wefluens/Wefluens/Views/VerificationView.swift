//
//  VerificationView.swift
//  Wefluens
//
//  6-digit email verification (OTP) screen shown after sign-up.
//

import SwiftUI
import Combine

struct VerificationView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(LocalizationManager.self) private var l10n

    @State private var code = ""
    @State private var secondsRemaining = 0
    @State private var showResentToast = false
    @FocusState private var isFocused: Bool

    private let codeLength = 6
    private let resendCooldown = 60
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 92, height: 92)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.coral.opacity(0.4), radius: 24, y: 8)

            Text(l10n.t(.authVerifyTitle))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 22)

            // Subtitle + target email
            VStack(spacing: 4) {
                Text(l10n.t(.authVerifySubtitle))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(auth.pendingEmail)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .padding(.horizontal, 32)

            Spacer()

            // Code boxes
            codeField
                .padding(.horizontal, 28)

            // Resent confirmation
            Text(l10n.t(.authCodeResent))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.coral)
                .opacity(showResentToast ? 1 : 0)
                .padding(.top, 14)

            Spacer()

            // Verify button
            Button {
                Task { await auth.verifyCode(code) }
            } label: {
                Group {
                    if auth.isVerifying {
                        ProgressView().tint(.black)
                    } else {
                        Text(l10n.t(.authVerifyButton))
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .background(.white)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(canVerify ? 1 : 0.5)
            .disabled(!canVerify)
            .padding(.horizontal, 32)

            // Resend
            Button {
                Task {
                    await auth.resendCode()
                    if !auth.showError {
                        startCooldown()
                        flashResentToast()
                    }
                }
            } label: {
                if auth.isResending {
                    ProgressView().tint(.white)
                } else if secondsRemaining > 0 {
                    Text("\(l10n.t(.authResendIn)) \(secondsRemaining)s")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text(l10n.t(.authResendCode))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .disabled(secondsRemaining > 0 || auth.isResending)
            .padding(.top, 18)

            // Change email
            Button {
                auth.cancelVerification()
            } label: {
                Text(l10n.t(.authChangeEmail))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .onAppear {
            startCooldown()
            isFocused = true
        }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
        .onChange(of: code) { _, newValue in
            // Keep digits only and auto-submit when full.
            let filtered = String(newValue.filter(\.isNumber).prefix(codeLength))
            if filtered != newValue { code = filtered }
            if filtered.count == codeLength {
                isFocused = false
                Task { await auth.verifyCode(filtered) }
            }
        }
    }

    private var canVerify: Bool {
        code.count == codeLength && !auth.isVerifying
    }

    // MARK: - Code field

    private var codeField: some View {
        ZStack {
            // Hidden input that captures keystrokes.
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(maxWidth: .infinity)
                .opacity(0)

            HStack(spacing: 8) {
                ForEach(0..<codeLength, id: \.self) { index in
                    digitBox(at: index)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func digitBox(at index: Int) -> some View {
        let chars = Array(code)
        let digit = index < chars.count ? String(chars[index]) : ""
        let isActive = (index == chars.count) && isFocused

        return Text(digit)
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Theme.coral : .white.opacity(0.18),
                            lineWidth: isActive ? 2 : 1)
            )
            .animation(.easeOut(duration: 0.15), value: isActive)
    }

    // MARK: - Helpers

    private func startCooldown() {
        secondsRemaining = resendCooldown
    }

    private func flashResentToast() {
        withAnimation(.easeIn(duration: 0.2)) { showResentToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) { showResentToast = false }
        }
    }
}

#Preview {
    ZStack {
        Theme.dusk.ignoresSafeArea()
        VerificationView()
            .environment(AuthManager())
            .environment(LocalizationManager())
    }
}
