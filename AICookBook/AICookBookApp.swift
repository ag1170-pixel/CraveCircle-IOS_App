//
//  AICookBookApp.swift
//  AICookBook
//
//  Created by Aniket Anand on 27/04/26.
//

import SwiftUI
import UserNotifications
import WidgetKit
import UIKit

/// Presents local notifications (Recipe Ready, cook-nudge, "shared with you") as banners even while
/// the app is in the foreground — otherwise iOS silently suppresses them and the user misses the info.
/// Also routes a tapped "recipe ready" push to the finished recipe.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            AppEnvironment.shared?.handlePushOpen(response.notification.request.content.userInfo)
        }
    }
}

/// UIKit application delegate — only for remote-notification (APNs) plumbing, which SwiftUI's App
/// lifecycle doesn't surface. DORMANT until Push Notifications is enabled on a paid Apple team:
/// `registerForRemoteNotifications()` simply calls `didFailToRegister` on the simulator / free team,
/// which we swallow quietly. Nothing else in the app depends on it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// A quick action chosen at cold launch, applied once the app is active (env is ready).
    static var pendingShortcut: String?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        application.shortcutItems = Self.shortcutItems()
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            Self.pendingShortcut = item.type
        }
        return true
    }

    // Home-screen quick actions (long-press the app icon): Write to CEO · Search · Grocery.
    static func shortcutItems() -> [UIApplicationShortcutItem] {
        [
            UIApplicationShortcutItem(type: "writeCEO", localizedTitle: "Write to CEO",
                                      localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "envelope.fill")),
            UIApplicationShortcutItem(type: "search", localizedTitle: "Search",
                                      localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass")),
            UIApplicationShortcutItem(type: "grocery", localizedTitle: "Grocery",
                                      localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "basket.fill")),
        ]
    }

    // Fallback for the (rare) no-scene case.
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        Self.handleShortcut(shortcutItem.type)
        completionHandler(true)
    }

    // SwiftUI apps are scene-based: a quick action on a RUNNING app is delivered to the SCENE
    // delegate (not the app delegate). Attach our own scene delegate so those actions get handled.
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = ShortcutSceneDelegate.self
        return config
    }

    /// Route a quick action into the app via the existing pending-action flags.
    static func handleShortcut(_ type: String) {
        Task { @MainActor in
            guard let env = AppEnvironment.shared else { pendingShortcut = type; return }
            switch type {
            case "search":   env.requestTabSwitch(.home)
            case "grocery":  env.requestTabSwitch(.groceries)
            case "writeCEO": env.pendingFeedback = true
            default: break
            }
        }
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        Task { @MainActor in AppEnvironment.shared?.registerAPNSToken(deviceToken, environment: env) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected on the simulator and on a free signing team (no aps-environment entitlement).
        print("ℹ️ Remote notifications unavailable: \(error.localizedDescription)")
    }
}

/// Minimal scene delegate that only handles Home-screen quick actions. It does NOT create a window,
/// so SwiftUI's WindowGroup still drives the UI.
final class ShortcutSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem {   // cold-launch via a quick action
            AppDelegate.pendingShortcut = item.type
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        AppDelegate.handleShortcut(shortcutItem.type)   // quick action while the app is running/backgrounded
        completionHandler(true)
    }
}

/// Ask for notification permission and, if granted, register for remote (APNs) pushes so the server
/// can say "your recipe is ready" after a background share-import. Harmless where APNs isn't set up.
@MainActor func requestPushAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        guard granted else { return }
        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
    }
}

@main
struct CraveCircleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                    // Tapping the in-progress "cooking" Live Activity just brings the app forward —
                    // the live import progress UI is already on screen.
                    if isCustomScheme && url.host == "import" && (url.query ?? "").isEmpty { return }

                    // Home-screen widget quick actions.
                    if isCustomScheme {
                        switch url.host {
                        case "grocery": environment.requestTabSwitch(.groceries); return
                        case "home":    environment.requestTabSwitch(.home); return
                        case "add":     environment.requestTabSwitch(.home); environment.pendingImportRequest = true; return
                        case "new":     environment.requestTabSwitch(.home); environment.pendingNewRecipe = true; return
                        default: break
                        }
                    }

                    let pathComponents = url.pathComponents.filter { $0 != "/" }
                    
                    // Format: cravecircle://recipe/<id> OR https://cravecircle.cc/recipe/<id>
                    if (isCustomScheme && url.host == "recipe") || (isUniversalLink && pathComponents.first == "recipe") {
                        let id = url.lastPathComponent
                        if !id.isEmpty, id != "/" { environment.openRecipe(id: id) }
                    } else {
                        // Share Extension. Prefer the server job id → resume the live progress UI and
                        // file the recipe as the user's. Fall back to a carried ?url= (legacy), else
                        // just refresh (the recipe is being built server-side and will land shortly).
                        // Parse robustly: URLComponents can miss query items on a custom-scheme URL,
                        // so fall back to splitting url.query ourselves.
                        func queryValue(_ key: String) -> String? {
                            if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                .queryItems?.first(where: { $0.name == key })?.value { return v }
                            return url.query?.split(separator: "&").compactMap { pair -> String? in
                                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                                return kv.count == 2 && kv[0] == key ? (kv[1].removingPercentEncoding ?? kv[1]) : nil
                            }.first
                        }
                        if let job = queryValue("job"), !job.isEmpty {
                            environment.resumeSharedImport(jobId: job)
                        } else if let shared = queryValue("url"), !shared.isEmpty {
                            Task { await environment.importFromSharedURL(shared); await environment.refreshRecipes() }
                        } else {
                            Task { await environment.checkPendingSharedImport(); await environment.refreshRecipes() }
                        }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    // On foreground, pull any reel the Share Extension imported server-side. A shared
                    // reel finishes processing ~1-2 min AFTER the share, so refresh a few times over
                    // ~90s so it appears on its own without the user pulling to refresh.
                    if phase == .active {
                        if environment.appState == .signedIn { requestPushAuthorization() }
                        // Apply a quick action chosen at cold launch (app wasn't running yet).
                        if let s = AppDelegate.pendingShortcut {
                            AppDelegate.pendingShortcut = nil
                            AppDelegate.handleShortcut(s)
                        }
                        environment.checkPendingSharedImport()   // resume a share's server job (paid-team App Group)
                        Task {
                            await environment.importFromSharedURL()
                            for gap in [UInt64(0), 30, 60] {   // refresh at ~0s, ~30s, ~90s
                                if gap > 0 { try? await Task.sleep(nanoseconds: gap * 1_000_000_000) }
                                if scenePhase != .active { break }
                                await environment.refreshRecipes()
                            }
                        }
                    }
                }
                .onAppear {
                    // Cold-launch check: scenePhase is already .active at launch so onChange doesn't fire.
                    environment.checkPendingSharedImport()
                    Task { await environment.importFromSharedURL() }
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
