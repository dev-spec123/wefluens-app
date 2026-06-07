//
//  ContentView.swift
//  Wefluens
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
        Group {
            if auth.isLoading {
                launchScreen
            } else if auth.isAuthenticated, let uid = auth.userId {
                if let ds = dataService {
                    RootTabView()
                        .environment(ds)
                        .transition(.opacity)
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
                            // Then check admin status — profile must exist for this to work
                            await auth.checkAdminStatus()
                            await ds.loadConversations()
                            await ds.loadContacts()
                            await ds.loadDiscover()
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
        .onChange(of: auth.isAuthenticated) { _, authenticated in
            if !authenticated {
                dataService = nil
            }
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
