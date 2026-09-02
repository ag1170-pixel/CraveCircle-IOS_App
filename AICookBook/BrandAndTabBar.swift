//
//  BrandAndTabBar.swift
//  CraveCircle (AICookBook)
//
//  The CraveCircle chef-hat mark (drawn, crisp at any size) and the clean floating
//  dark liquid-glass tab bar — matched to the Figma / marketing shot.
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
        case .home: return "house.fill"
        case .studio: return "square.and.pencil"
        case .groceries: return "basket.fill"
        case .search: return "magnifyingglass"
        case .profile: return "person.fill"
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

// MARK: - Floating dark-pill tab bar

struct CraveTabBar: View {
    @Binding var selected: AppTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    Haptics.select()
                    selected = tab
                } label: {
                    ZStack {
                        if selected == tab {
                            Capsule(style: .continuous)
                                .fill(.white)
                                .matchedGeometryEffect(id: "tab", in: ns)
                        }
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected == tab ? Color(hex: "1B1A17") : Color.white.opacity(0.6))
                            .frame(width: 54, height: 42)
                    }
                    .frame(width: 54, height: 42)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)                       // real translucent glass
                .environment(\.colorScheme, .dark)              // render the glass dark
                .overlay(Capsule(style: .continuous).fill(.black.opacity(0.18)))  // tint for icon legibility
                .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.22), radius: 16, y: 6)
        }
        .animation(AppMotion.snappy, value: selected)
    }
}
