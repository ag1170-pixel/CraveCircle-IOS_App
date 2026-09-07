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

    init() {
        // Bounded image/URL cache so cached recipe photos self-evict and NEVER balloon device
        // storage (the usual reason people delete a media-heavy app). Applies to AsyncImage,
        // which uses URLSession.shared → URLCache.shared.
        URLCache.shared = URLCache(memoryCapacity: 16 * 1024 * 1024,   // 16 MB in RAM
                                   diskCapacity: 96 * 1024 * 1024)      // 96 MB on disk, LRU-evicted
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                // Dark-first design, full light + dark parity — follow the system appearance.
                .onOpenURL { url in
                    guard url.scheme == "cravecircle" else { return }
                    // cravecircle://recipe/<id> opens a shared recipe in-app; anything else is an import.
                    if url.host == "recipe" {
                        let id = url.lastPathComponent
                        if !id.isEmpty, id != "/" { environment.openRecipe(id: id) }
                    } else {
                        Task { await environment.importFromSharedURL() }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Also check on foreground, in case the app was cold-launched by the share.
                    if phase == .active {
                        Task { await environment.importFromSharedURL() }
                    }
                }
                .onAppear {
                    // Cold-launch check: scenePhase is already .active at launch so onChange doesn't fire.
                    Task { await environment.importFromSharedURL() }
                }
        }
    }
}
