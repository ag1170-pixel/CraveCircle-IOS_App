//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: DesignSystem.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Foundational design tokens defining spacing, typography scales, corner radii, and spring animations.
//
// 2. ARCHITECTURAL ROLE:
//    Constants and helpers: AppSpacing, AppRadius, AppFont, AppMotion, and standard layout metrics.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "DesignSystem standardizes our styling rules into tokens. By referencing AppSpacing.md or AppRadius.card instead of magic numbers, the entire app stays visually unified and adapts smoothly to Dynamic Type."
//
// ==============================================================================
//

//
//  DesignSystem.swift
//  CraveCircle (AICookBook)
//
//  DIRECTION CONTRACT — "Figma-matched, warm & social" (updated per Figma reference)
//  THESIS: A living cookbook where the food leads and friends are present. Light, warm,
//    appetizing; HIG-native bones with editorial food-photo heroes. Coral accent, a serif
//    CraveCircle wordmark, social-forward home (Following · Fresh in your Circle · Library).
//  OWN-WORLD: warm off-white/cream grounds, white cards, a single warm CORAL accent
//    (#EA5A38), serif wordmark over quiet SF body, hairline separators, no emoji. Ships
//    full light + dark parity; designed light-first to match the Figma.
//  Ref: Figma "AI CookBook" — Components page (Main Dashboard + recipePage), light & dark.
//

import SwiftUI
import UIKit

// Color helpers (init(light:dark:) / init(hex:)) live in Color+Theme.swift.

// MARK: - Theme tokens  (light-first warm/cream + coral; dark parity)

enum AppTheme {
    static let background = Color(light: Color(hex: "FAF8F3"), dark: Color(hex: "16130F"))
    static let surface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "201C17"))
    static let surfaceElevated = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "27231D"))
    static let separator = Color(light: Color(hex: "ECE7DC"), dark: Color(hex: "2E2A23"),
                                 highContrastLight: Color(hex: "C9C1B2"), highContrastDark: Color(hex: "555043"))
    static let hairline = Color(light: Color(hex: "E4DED0"), dark: Color(hex: "3A352C"),
                                highContrastLight: Color(hex: "B5AC9B"), highContrastDark: Color(hex: "6A6356"))

    static let textPrimary = Color(light: Color(hex: "1B1712"), dark: Color(hex: "F6F3EC"),
                                   highContrastLight: .black, highContrastDark: .white)
    static let textSecondary = Color(light: Color(hex: "6B6355"), dark: Color(hex: "A8A090"),
                                     highContrastLight: Color(hex: "4F483D"), highContrastDark: Color(hex: "C9C1B2"))
    // 4.5:1+ against both backgrounds. The old #9A9182 / #6E675A was ~2.9–3.3:1.
    static let textTertiary = Color(light: Color(hex: "746C5E"), dark: Color(hex: "9A9282"),
                                    highContrastLight: Color(hex: "5F574A"), highContrastDark: Color(hex: "C9C1B2"))

    // The single accent — warm coral (Figma). `accent` fills; `accentInk` is text-safe.
    // Monochrome charcoal accent — near-black in light, near-white in dark (stays visible in both).
    static let accent = Color(light: Color(hex: "1B1A17"), dark: Color(hex: "F2EFE8"))
    static let onAccent = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "1B1A17"))  // text on the accent fill
    static let accentInk = Color(light: Color(hex: "1B1A17"), dark: Color(hex: "F2EFE8"))
    static let accentSoft = Color(light: Color(hex: "EDEBE4"), dark: Color(hex: "2A2822"))

    // Brand primary — CraveCircle warm coral. Identity color, NOT the UI action accent (that's the
    // charcoal `accent`). Same in light and dark so the brand reads consistently (e.g. the + FAB).
    static let brand = Color(hex: "EA5A38")
    static let onBrand = Color.white      // text/icon on the coral brand fill

    static let destructive = Color(light: Color(hex: "C7362A"), dark: Color(hex: "FF5A48"))
    static let scrim = Color.black

    /// Photo scrim gradient (the only gradient allowed — over food photography).
    static var heroScrim: LinearGradient {
        LinearGradient(
            colors: [.black.opacity(0.0), .black.opacity(0.12), .black.opacity(0.68)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Typography  (serif wordmark + SF Pro UI + Dynamic Type)

/// Fixed design sizes that still respond to Dynamic Type. Each size is scaled with
/// `UIFontMetrics` against the closest system text style, so the existing screens keep
/// their type scale while growing/shrinking with the user's preferred text size.
enum AppFont {
    /// The system text style whose scaling curve best matches a design point size.
    private static func textStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<12:  return .caption2
        case ..<13:  return .caption1
        case ..<14:  return .footnote
        case ..<15:  return .subheadline
        case ..<17:  return .callout
        case ..<20:  return .body
        case ..<22:  return .title3
        case ..<28:  return .title2
        case ..<34:  return .title1
        default:     return .largeTitle
        }
    }

    /// Current content-size category. `UITraitCollection.current` is set during a SwiftUI
    /// update, but fall back to the app-wide preference when it isn't (e.g. previews).
    private static var contentSizeCategory: UIContentSizeCategory {
        let current = UITraitCollection.current.preferredContentSizeCategory
        if current != .unspecified { return current }
        return UIApplication.shared.preferredContentSizeCategory
    }

    /// Applies the user's Dynamic Type setting to a fixed design size.
    /// Scaled with UIFontMetrics for the corresponding text style so text scales smoothly
    /// across all standard sizes and Apple's Accessibility Sizes (AX1 through AX5).
    private static func scaled(_ size: CGFloat) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: textStyle(for: size))
        let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory)
        return metrics.scaledValue(for: size, compatibleWith: traits)
    }

    /// Bold SF display for section headers and titles.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: scaled(size), weight: weight, design: .default)
    }

    /// Serif wordmark / brand voice (New York system serif — the CraveCircle logotype).
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: scaled(size), weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .default)
    }

    /// Monospaced — step numbers (01, 02), quantities, timers.
    static func mono(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size), weight: weight, design: .monospaced)
    }

    /// Uppercase tracked section label.
    static func label(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size), weight: weight, design: .default)
    }
}

// MARK: - Spacing / Radius / Motion scales

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40
}

enum AppRadius {
    static let sm: CGFloat = 10
    static let card: CGFloat = 16
    static let sheet: CGFloat = 24
    static let tile: CGFloat = 14
}

enum AppMotion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.86)
    static let gentle = Animation.easeOut(duration: 0.28)
}

// Section-label modifier (`sectionLabelStyle`) lives in View+SectionLabel.swift.
