//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: Color+Theme.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Color palette definitions supporting adaptive Light and Dark appearances.
//
// 2. ARCHITECTURAL ROLE:
//    Defines semantic colors (AppTheme.background, AppTheme.accent, AppTheme.cardBg) using dynamic asset catalog values.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "Color+Theme defines our cream and charcoal palette. It uses semantic color pairs that automatically adapt when the user switches between iOS Light and Dark mode, with high-contrast accessibility support."
//
// ==============================================================================
//

//
//  Color+Theme.swift
//  CraveCircle (AICookBook)
//
//  Color conveniences used across the app: an appearance-adaptive initializer and a hex initializer.
//

import SwiftUI
import UIKit

extension Color {
    /// Resolves differently in light vs dark appearance — full theme parity.
    /// Optional high-contrast variants are used when Increase Contrast is enabled.
    init(light: Color, dark: Color, highContrastLight: Color? = nil, highContrastDark: Color? = nil) {
        self = Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            if traits.accessibilityContrast == .high {
                return UIColor(isDark ? (highContrastDark ?? dark) : (highContrastLight ?? light))
            }
            return isDark ? UIColor(dark) : UIColor(light)
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
