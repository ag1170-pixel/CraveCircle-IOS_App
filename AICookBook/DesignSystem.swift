import SwiftUI

enum AppTheme {
    static let background = Color(hex: "FFFFFF")
    static let surface = Color(hex: "F3F4F6")
    static let surfaceElevated = Color(hex: "FFFFFF").opacity(0.82)
    static let separator = Color(hex: "E5E7EB")

    static let textPrimary = Color(hex: "0B0B0F")
    static let textSecondary = Color(hex: "4B5563")
    static let textTertiary = Color(hex: "6B7280")

    static let accent = Color(hex: "D4F73F")
    static let destructive = Color.red
}

enum AppFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat = 16, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

