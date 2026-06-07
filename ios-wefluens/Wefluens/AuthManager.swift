//
//  AuthManager.swift
//  Wefluens
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

        // Listen for future auth changes
        Task {
            for await state in supabase.auth.authStateChanges {
                await MainActor.run {
                    switch state.event {
                    case .signedIn:
                        session = state.session
                        isAuthenticated = true
                    case .signedOut:
                        session = nil
                        isAuthenticated = false
                    default:
                        break
                    }
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
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() async {
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
