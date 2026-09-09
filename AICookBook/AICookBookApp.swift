//
//  AICookBookApp.swift
//  AICookBook
//
//  Created by Aniket Anand on 27/04/26.
//

import SwiftUI
import UserNotifications

/// Presents local notifications (Recipe Ready, cook-nudge, "shared with you") as banners even while
/// the app is in the foreground — otherwise iOS silently suppresses them and the user misses the info.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

@main
struct CraveCircleApp: App {
    @StateObject private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Bounded image/URL cache so cached recipe photos self-evict and NEVER balloon device
        // storage (the usual reason people delete a media-heavy app). Applies to AsyncImage,
        // which uses URLSession.shared → URLCache.shared.
        URLCache.shared = URLCache(memoryCapacity: 16 * 1024 * 1024,   // 16 MB in RAM
                                   diskCapacity: 96 * 1024 * 1024)      // 96 MB on disk, LRU-evicted
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                // Dark-first design, full light + dark parity — follow the system appearance.
                .onOpenURL { url in
                    // Support both the legacy cravecircle:// custom scheme and standard https Universal Links.
                    let isCustomScheme = url.scheme == "cravecircle"
                    let isUniversalLink = (url.scheme == "https" || url.scheme == "http") && url.host == "cravecircle.cc"
                    guard isCustomScheme || isUniversalLink else { return }
                    if isCustomScheme && url.host == "auth-callback" { return }
                    
                    let pathComponents = url.pathComponents.filter { $0 != "/" }
                    
                    // Format: cravecircle://recipe/<id> OR https://cravecircle.cc/recipe/<id>
                    if (isCustomScheme && url.host == "recipe") || (isUniversalLink && pathComponents.first == "recipe") {
                        let id = url.lastPathComponent
                        if !id.isEmpty, id != "/" { environment.openRecipe(id: id) }
                    } else {
                        // Share Extension: the reel is imported server-side by the extension, so pull
                        // the new recipe into the library. (A ?url= — older hand-off path — still imports.)
                        let shared = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "url" })?.value
                        Task {
                            await environment.importFromSharedURL(shared)
                            await environment.refreshRecipes()
                        }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // On foreground, pull any reel the Share Extension imported server-side while we
                    // were away (this is how a shared reel shows up when the extension can't open us).
                    if phase == .active {
                        Task {
                            await environment.importFromSharedURL()
                            await environment.refreshRecipes()
                        }
                    }
                }
                .onAppear {
                    // Cold-launch check: scenePhase is already .active at launch so onChange doesn't fire.
                    Task { await environment.importFromSharedURL() }
                }
        }
    }
}
