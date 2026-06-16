//
//  AuthManager.swift
//  WeConnect
//
//  Native Supabase Auth — invite-only sign-in.
//  Accounts are created by an admin invite (see AdminUsersView + the
//  invite-user / activate-invite edge functions). There is no public sign-up.
//

import SwiftUI
import Supabase

@Observable
final class AuthManager {
    var isAuthenticated = false
    var isLoading = true
    var isSigningIn = false
    var showError = false
    var errorMessage = ""
    var isAdmin = false

    /// Deep-link redirect targets. The `wefluens` URL scheme is registered in
    /// Info.plist; these hosts must also be added to the Supabase project's
    /// "Additional Redirect URLs" allow-list.
    static let resetRedirectURL = URL(string: "wefluens://reset-password")!
    static let signUpRedirectURL = URL(string: "wefluens://auth-callback")!

    /// Set after a successful sign-up when email confirmation is required
    /// (no session returned). Drives the "check your email" screen.
    var signUpNeedsConfirmation = false
    /// The address a confirmation link was sent to (shown on that screen).
    var pendingConfirmationEmail = ""

    /// True while the app is in a password-recovery session opened from a reset
    /// deep link. Drives the full-screen "set new password" cover.
    var passwordRecoveryActive = false

    /// True when the signed-in user must change their initial password before
    /// they can use the app. Set from the `must_change_password` profile flag.
    var mustChangePassword = false

    /// The authenticated user's UUID from Supabase Auth.
    var userId: UUID? {
        session?.user.id
    }

    /// The authenticated user's email.
    var userEmail: String? {
        session?.user.email
    }

    private var session: Auth.Session?

    /// Long-lived listener for Supabase auth-state changes. Stored so we can cancel
    /// it on sign-out and re-arm it on sign-in — never leaving multiple listeners
    /// stacked up across a long session.
    private var authStateTask: Task<Void, Never>?

    init() {
        Task { await checkAuth() }
    }

    // MARK: - Session

    @MainActor
    func checkAuth() async {
        defer { isLoading = false }

        do {
            session = try await supabase.auth.session
            isAuthenticated = true
        } catch {
            session = nil
            isAuthenticated = false
        }

        // Listen for future auth changes (cancels any prior listener first).
        startAuthStateListener()
    }

    /// Starts (or restarts) the single auth-state listener, cancelling any existing
    /// one first so repeated calls can never accumulate multiple subscriptions.
    private func startAuthStateListener() {
        authStateTask?.cancel()
        authStateTask = Task { [weak self] in
            for await state in supabase.auth.authStateChanges {
                guard let self else { return }
                switch state.event {
                case .passwordRecovery:
                    // A reset link was opened — keep the user out of the app and
                    // present the set-new-password screen instead.
                    self.session = state.session
                    self.passwordRecoveryActive = true
                case .signedIn:
                    self.session = state.session
                    self.isAuthenticated = true
                case .signedOut:
                    self.session = nil
                    self.isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    // MARK: - Sign In

    @MainActor
    func signIn(email: String, password: String) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            isAuthenticated = true
            // Re-arm the listener for this fresh session (idempotent — cancels first).
            startAuthStateListener()
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Sign Up

    @MainActor
    func signUp(email: String, password: String) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                redirectTo: Self.signUpRedirectURL
            )
            // If email confirmation is disabled, a session is returned and the user
            // is signed in immediately; otherwise they'll confirm via email.
            if let newSession = response.session {
                session = newSession
                isAuthenticated = true
                startAuthStateListener()
            } else {
                pendingConfirmationEmail = email
                signUpNeedsConfirmation = true
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    /// Resets the sign-up confirmation screen back to the sign-in form.
    @MainActor
    func cancelSignUpConfirmation() {
        signUpNeedsConfirmation = false
        pendingConfirmationEmail = ""
    }

    // MARK: - Password Reset

    /// Sends a password-reset email. Always resolves without revealing whether the
    /// address exists; surfaces only genuine transport errors.
    @MainActor
    func sendPasswordReset(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(
            email,
            redirectTo: Self.resetRedirectURL
        )
    }

    // MARK: - Deep Links

    /// Handles an incoming deep link (sign-up confirmation or password reset).
    /// Exchanges the link for a session; the auth-state listener then either
    /// signs the user in or flips `passwordRecoveryActive` for recovery links.
    @MainActor
    func handleDeepLink(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
            // Recovery links sometimes surface as a plain sign-in; if the host
            // says reset, force the recovery screen regardless of event order.
            if url.host == "reset-password" {
                passwordRecoveryActive = true
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    /// Updates the password for the active recovery session, then signs out so
    /// the user logs in fresh with the new credentials.
    @MainActor
    func updateRecoveredPassword(to newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
        passwordRecoveryActive = false
        try? await supabase.auth.signOut()
        session = nil
        isAuthenticated = false
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() async {
        // Stop observing auth changes before tearing down the session so the listener
        // can't linger; signIn() re-arms it on the next login.
        authStateTask?.cancel()
        authStateTask = nil
        do {
            try await supabase.auth.signOut()
        } catch {
            print("⚠️ Sign out error: \(error)")
        }
        session = nil
        isAuthenticated = false
        isAdmin = false
        mustChangePassword = false
    }

    // MARK: - Account flags (admin + forced password change)

    @MainActor
    func checkAccountFlags() async {
        guard let uid = userId else { return }
        do {
            struct Flags: Codable {
                let isAdmin: Bool?
                let mustChangePassword: Bool?
                enum CodingKeys: String, CodingKey {
                    case isAdmin = "is_admin"
                    case mustChangePassword = "must_change_password"
                }
            }
            let rows: [Flags] = try await supabase
                .from("profiles")
                .select("is_admin,must_change_password")
                .eq("id", value: uid.uuidString)
                .execute()
                .value
            isAdmin = rows.first?.isAdmin ?? false
            mustChangePassword = rows.first?.mustChangePassword ?? false
        } catch {
            print("⚠️ Account flags check failed: \(error)")
            isAdmin = false
        }
    }

    // MARK: - Change Password

    /// Updates the signed-in user's password and clears the forced-change flag.
    /// Throws so the caller can surface a meaningful message.
    @MainActor
    func changePassword(to newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))

        if let uid = userId {
            struct PasswordFlagUpdate: Encodable, Sendable {
                let must_change_password: Bool
            }
            try await supabase
                .from("profiles")
                .update(PasswordFlagUpdate(must_change_password: false))
                .eq("id", value: uid.uuidString)
                .execute()
        }
        mustChangePassword = false
    }

    // MARK: - Helpers

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
