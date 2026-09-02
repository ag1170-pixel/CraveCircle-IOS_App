//
//  AICookBookApp.swift
//  AICookBook
//
//  Created by Aniket Anand on 27/04/26.
//

import SwiftUI

@main
struct AICookBookApp: App {
    @StateObject private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                // Dark-first design, full light + dark parity — follow the system appearance.
                // A reel shared from Instagram / YouTube / TikTok arrives via the Share Extension,
                // which stashes the link in the App Group and opens cravecircle://import.
                .onOpenURL { url in
                    guard url.scheme == "cravecircle" else { return }
                    Task { await environment.importFromSharedURL() }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Also check on foreground, in case the app was cold-launched by the share.
                    if phase == .active {
                        Task { await environment.importFromSharedURL() }
                    }
                }
        }
    }
}
