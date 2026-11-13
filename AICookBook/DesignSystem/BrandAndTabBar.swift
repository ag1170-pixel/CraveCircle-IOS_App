//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: BrandAndTabBar.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Custom floating glass tab bar and brand navigation headers.
//
// 2. ARCHITECTURAL ROLE:
//    Bottom navigation bar featuring translucent glass material blur, active tab indicators, and quick-action import trigger.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "BrandAndTabBar replaces the default UIKit tab bar with an Apple-style floating glass bar. It features subtle spring animations on selection and an elevated center import button."
//
// ==============================================================================
//

//
//  BrandAndTabBar.swift
//  CraveCircle (AICookBook)
//
//  Brand lockup + tab identifiers. The bottom bar itself is the system iOS 26
//  TabView (same path Instagram uses) — see MainTabView.
//

import SwiftUI

// MARK: - Chef-hat logo mark

// MARK: - SwiftUI View Component
struct ChefHatLogo: View {
    var size: CGFloat = 28
    var color: Color = Color(hex: "D6572F")   // brand coral chef-hat (stays coral even with charcoal UI accent)

    var body: some View {
        Image("CraveCircleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Tabs

enum AppTab: CaseIterable, Hashable {
    // Order = tab bar order. Import is NOT a tab — it's a floating round FAB (Osta-style,
    // bottom-right) that opens the Add-a-recipe sheet. The old Studio/"Create" tab was removed.
    case home, discover, groceries, profile

    var icon: String {
        switch self {
        case .home: return "house"
        case .discover: return "safari"
        case .groceries: return "basket"
        case .profile: return "person"
        }
    }
    var title: String {
        switch self {
        case .home: return "Home"
        case .discover: return "Discover"
        case .groceries: return "Grocery"
        case .profile: return "Profile"
        }
    }

    /// Next tab in order (clamped at end).
    var next: AppTab? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), all.index(after: i) < all.endIndex else { return nil }
        return all[all.index(after: i)]
    }
    /// Previous tab in order (clamped at start).
    var previous: AppTab? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i > all.startIndex else { return nil }
        return all[all.index(before: i)]
    }
}

