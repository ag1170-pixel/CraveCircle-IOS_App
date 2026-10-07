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

// MARK: - Adaptive color helper

extension Color {
    /// Resolves differently in light vs dark appearance — full theme parity.
    init(light: Color, dark: Color) {
        self = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

// MARK: - Theme tokens  (light-first warm/cream + coral; dark parity)

enum AppTheme {
    static let background = Color(light: Color(hex: "FAF8F3"), dark: Color(hex: "16130F"))
    static let surface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "201C17"))
    static let surfaceElevated = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "27231D"))
    static let separator = Color(light: Color(hex: "ECE7DC"), dark: Color(hex: "2E2A23"))
    static let hairline = Color(light: Color(hex: "E4DED0"), dark: Color(hex: "3A352C"))

    static let textPrimary = Color(light: Color(hex: "1B1712"), dark: Color(hex: "F6F3EC"))
    static let textSecondary = Color(light: Color(hex: "6B6355"), dark: Color(hex: "A8A090"))
    static let textTertiary = Color(light: Color(hex: "9A9182"), dark: Color(hex: "6E675A"))

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

enum AppFont {
    /// Bold SF display for section headers and titles.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Serif wordmark / brand voice (New York system serif — the CraveCircle logotype).
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Monospaced — step numbers (01, 02), quantities, timers.
    static func mono(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Uppercase tracked section label.
    static func label(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
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

// MARK: - Section label modifier

extension View {
    func sectionLabelStyle(_ color: Color = AppTheme.textSecondary) -> some View {
        self.font(AppFont.label(13, weight: .semibold))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
