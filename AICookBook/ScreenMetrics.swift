//
//  ScreenMetrics.swift
//  CraveCircle (AICookBook)
//
//  The size of the screen the app is showing on, read through the active window scene.
//  `UIScreen.main` is deprecated in iOS 26 (an app can be on more than one screen), and Apple's
//  replacement is "the UIScreen found through context", i.e. `windowScene.screen`.
//

import UIKit

enum ScreenMetrics {
    @MainActor static var bounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        // Fallback only before any scene connects (never while a view is on screen): a 6.1" iPhone.
        return scene?.screen.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
    }
}
