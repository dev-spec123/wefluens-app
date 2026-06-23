//
//  ContentView.swift
//  WeConnect
//
//  Root screen that gates on authentication state.
//  Creates AppDataService lazily only after auth is confirmed,
//  eliminating the nil-userId window.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @State private var dataService: AppDataService?

    var body: some View {
        @Bindable var auth = auth

        return Group {
            if auth.isLoading {
                launchScreen
            } else if auth.isAuthenticated, let uid = auth.userId {
                if let ds = dataService {
                    if auth.mustChangePassword {
                        ForcePasswordChangeView()
                            .transition(.opacity)
                    } else {
                        RootTabView()
                            .environment(ds)
                            .transition(.opacity)
                    }
                } else {
                    // Brief loading while we set up the data service
                    ProgressView()
                        .tint(Theme.coral)
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.paper(for: .light).ignoresSafeArea())
                        .task {
                            let ds = AppDataService(userId: uid)
                            // Sync profile first — this creates the profile row if it doesn't exist
                            await ds.syncProfile(userId: uid, email: auth.userEmail)
                            // Then read account flags (admin + forced password change) — profile must exist for this to work
                            await auth.checkAccountFlags()
                            // Load my block list before conversations/contacts so blocked users are filtered out.
                            await ds.loadBlocks()
                            // If the user just agreed to the terms at sign-up, stamp acceptance once.
                            if UserDefaults.standard.bool(forKey: AuthView.pendingTermsKey) {
                                await ds.acceptTerms()
                                UserDefaults.standard.removeObject(forKey: AuthView.pendingTermsKey)
                            }
                            await ds.loadConversations()
                            await ds.loadContacts()
                            await ds.loadDiscover()
                            await ds.favorites.loadFromCloud()
                            // Push: upload any APNs token to this user's device_tokens,
                            // and (without prompting) refresh it if they're opted in.
                            PushService.shared.onToken = { token in
                                Task { await ds.registerDeviceToken(token) }
                            }
                            if ds.profile?.notificationsEnabled == true {
                                await PushService.shared.registerIfAuthorized()
                            }
                            withAnimation(.easeInOut(duration: 0.3)) {
                                dataService = ds
                            }
                        }
                }
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: auth.isLoading)
        .animation(.easeInOut(duration: 0.35), value: auth.mustChangePassword)
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if !authenticated {
                dataService = nil
            }
        }
        .onOpenURL { url in
            Task { await auth.handleDeepLink(url) }
        }
        .fullScreenCover(isPresented: $auth.passwordRecoveryActive) {
            SetNewPasswordView()
        }
    }

    private var launchScreen: some View {
        ZStack {
            Theme.dusk.ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
        .environment(LocalizationManager())
        .environment(ThemeManager())
}
