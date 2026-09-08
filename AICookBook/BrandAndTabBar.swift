//
//  BrandAndTabBar.swift
//  CraveCircle (AICookBook)
//
//  Brand lockup + tab identifiers. The bottom bar itself is the system iOS 26
//  TabView (same path Instagram uses) — see MainTabView.
//

import SwiftUI

// MARK: - Chef-hat logo mark

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

/// Logo + serif wordmark lockup used in top bars.
struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 8) {
            ChefHatLogo(size: 26)
            Text("CraveCircle")
                .font(AppFont.serif(21, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

// MARK: - Tabs

enum AppTab: CaseIterable, Hashable {
    case home, studio, groceries, search, profile

    var icon: String {
        switch self {
        case .home: return "house"
        case .studio: return "square.and.pencil"
        case .groceries: return "basket"
        case .search: return "magnifyingglass"
        case .profile: return "person"
        }
    }
    var title: String {
        switch self {
        case .home: return "Home"
        case .studio: return "Studio"
        case .groceries: return "Grocery"
        case .search: return "Search"
        case .profile: return "Profile"
        }
    }
}

