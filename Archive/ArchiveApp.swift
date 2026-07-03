//
//  ArchiveApp.swift
//  Archive
//
//  Created by Matthew Lu on 7/3/26.
//

import SwiftUI
import GoogleSignIn

@main
struct ArchiveApp: App {
    @State private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

/// Routes between auth and the main app based on session state,
/// and drains any share-extension URLs queued while the app was closed.
struct RootView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView()
            } else if auth.isSignedIn {
                MainTabView()
                    .task { await drainPendingShares() }
            } else {
                AuthView()
                #if DEBUG
                    .task { await debugAutoLogin() }
                #endif
            }
        }
        .animation(.default, value: auth.isSignedIn)
    }

    #if DEBUG
    /// Signs in automatically when launched with DEBUG_EMAIL/DEBUG_PASSWORD
    /// env vars (e.g. via `simctl launch`) — used for automated verification.
    private func debugAutoLogin() async {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["DEBUG_EMAIL"], let password = env["DEBUG_PASSWORD"] else { return }
        await auth.signIn(email: email, password: password)
    }
    #endif

    private func drainPendingShares() async {
        let queue = PendingShareQueue()
        guard !queue.isEmpty else { return }
        let ingest = VideoIngestService()
        for url in queue.drain() {
            _ = try? await ingest.ingest(url: url)
        }
        NotificationCenter.default.post(name: .archivesDidChange, object: nil)
    }
}

extension Notification.Name {
    /// Posted after background ingests so visible lists can refresh.
    static let archivesDidChange = Notification.Name("archivesDidChange")
}
