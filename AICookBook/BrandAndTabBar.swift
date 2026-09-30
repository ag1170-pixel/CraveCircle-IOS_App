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
    // Order shown in the tab bar (left → right): Home, Discover, Grocery, Profile.
    // Studio is reachable elsewhere (profile) and intentionally not in the bar.
    case home, discover, groceries, profile

    var icon: String {
        switch self {
        case .home: return "house"
        case .discover: return "magnifyingglass"
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
}

// MARK: - Floating glass tab bar (Apple-fluid, premium)
//
// A floating pill of adaptive "liquid glass" (light material in light mode, dark in dark), with a
// single selected tab that expands to reveal its label. SF Symbols fill + give a soft bounce on
// select; the selected pill slides between tabs with a matched-geometry spring; press gives instant
// scale feedback. Honors Reduce Motion. Warm, restrained palette — reads premium on the cream app.

struct CraveTabBar: View {
    @Binding var selected: AppTab
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The floating glass pill (shape kept), stretched WIDE like Instagram: icons evenly spread
        // across the full width with a small margin from the screen edges.
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background {
            Capsule(style: .continuous)
                .fill(.regularMaterial)                     // adaptive translucent glass
                .overlay(                                   // bright top edge = light catching the material
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.04)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        // horizontal padding is applied by the caller so the pill can share a row with the
        // floating Import button (see MainTabView).
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selected == tab
        Button {
            guard !isSelected else { return }
            Haptics.select()
            withAnimation(reduceMotion
                          ? .easeOut(duration: 0.2)
                          : .spring(response: 0.4, dampingFraction: 0.82)) {
                selected = tab
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 18, weight: .semibold))
                .symbolVariant(isSelected ? .fill : .none)
                .symbolEffect(.bounce, value: isSelected)      // a little delight on select
                .foregroundStyle(isSelected ? AppTheme.accentInk : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)                     // even spread across the wide pill
                .frame(height: 40)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(AppTheme.accentSoft)
                            .matchedGeometryEffect(id: "tabpill", in: ns)
                            .padding(.horizontal, 10)           // rounded highlight around the icon
                    }
                }
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

// MARK: - Floating Import button (Osta-style)
//
// A round accent-filled button that sits to the right of the tab bar. Tapping it opens the same
// import sheet the old top-nav download icon used, so importing is one tap from anywhere.

struct ImportFAB: View {
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(AppTheme.accent)
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.05)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 0.75)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(TabPressStyle())
        .accessibilityLabel("Import recipe")
    }
}
