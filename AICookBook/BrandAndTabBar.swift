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

// MARK: - Floating glass tab bar (Apple-fluid, premium)
//
// A floating pill of adaptive "liquid glass" (light material in light mode, dark in dark), with a
// single selected tab that expands to reveal its label. SF Symbols fill + give a soft bounce on
// select; the selected pill slides between tabs with a matched-geometry spring; press gives instant
// scale feedback. Honors Reduce Motion. Warm, restrained palette — reads premium on the cream app.

struct CraveTabBar: View {
    @Binding var selected: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Full-width bar flush to the bottom (Instagram-style): five evenly-spaced icons, a thin
        // top divider, and a material background that extends under the home indicator.
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .background(alignment: .top) {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(AppTheme.separator).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selected == tab
        Button {
            guard !isSelected else { return }
            Haptics.select()
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.8)) {
                selected = tab
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 23, weight: .regular))
                .symbolVariant(isSelected ? .fill : .none)
                .symbolEffect(.bounce, value: isSelected)      // a little delight on select
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)                     // even spread across the full width
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(TabPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Instant, subtle press feedback (respond on touch-down, spring back on release).
private struct TabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
