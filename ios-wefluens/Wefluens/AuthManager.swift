//
//  AuthManager.swift
//  Wefluens
//
//  Native Supabase Auth — email/password sign-up and sign-in.
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
    var showVerificationSent = false

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

    // MARK: - Sign Up

    @MainActor
    func signUp(email: String, password: String) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            session = response.session
            isAuthenticated = session != nil

            if session == nil {
                // Email confirmation required — show verification-sent popup
                showVerificationSent = true
            }
        } catch {
            setError(error.localizedDescription)
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
    }

    // MARK: - Admin

    @MainActor
    func checkAdminStatus() async {
        guard let uid = userId else { return }
        do {
            struct AdminCheck: Codable {
                let isAdmin: Bool?
                enum CodingKeys: String, CodingKey {
                    case isAdmin = "is_admin"
                }
            }
            let rows: [AdminCheck] = try await supabase
                .from("profiles")
                .select("is_admin")
                .eq("id", value: uid.uuidString)
                .execute()
                .value
            isAdmin = rows.first?.isAdmin ?? false
        } catch {
            print("⚠️ Admin check failed: \(error)")
            isAdmin = false
        }
    }

    // MARK: - Helpers

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
