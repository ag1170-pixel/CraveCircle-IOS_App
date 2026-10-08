//
//  DesignComponents.swift
//  CraveCircle (AICookBook)
//
//  Reusable Fusion primitives: pill buttons, a custom lime segmented control,
//  checkable rows, glass overlay buttons, chips, and haptics.
//

import SwiftUI
import UIKit

// MARK: - Randomized doodle wallpaper

/// The food-doodle art (`DoodleBG`, 2578×1716) treated as a 4×3 board of 12 cells. `cell` (0..<12)
/// picks one and fills the screen with just that patch, so each screen shows a different slice; the
/// app reshuffles `cell` on every navigation (see `AppEnvironment.shuffleDoodle`). Dark-theme art
/// only — light mode falls back to the plain app background (a light wallpaper can be added later).
/// Purely decorative and never interactive.
struct DoodleWallpaper: View {
    var cell: Int
    @Environment(\.colorScheme) private var scheme

    private let cols = 4, rows = 3
    private let imgW: CGFloat = 10272, imgH: CGFloat = 6864   // "Background(2)" dense doodle tile

    var body: some View {
        ZStack {
            AppTheme.background   // base (dark in dark mode, cream in light) — never inverted
            GeometryReader { geo in
                let cw = geo.size.width, ch = geo.size.height
                // Zoomed-out, dense art (small doodles). Fill the screen then PAN to 1 of 12
                // positions so each screen shows a different patch; the small extra `zoom` over
                // the fill scale buys pan room on both axes for the 4×3 grid.
                let fill = max(cw / imgW, ch / imgH)
                let zoom = fill * 1.15
                let sw = imgW * zoom, sh = imgH * zoom
                let ox = max(sw - cw, 0), oy = max(sh - ch, 0)
                let n = cols * rows
                let c = ((cell % n) + n) % n
                let col = CGFloat(c % cols), row = CGFloat(c / cols)
                let fx = cols > 1 ? col / CGFloat(cols - 1) : 0.5
                let fy = rows > 1 ? row / CGFloat(rows - 1) : 0.5
                doodle(sw: sw, sh: sh, ox: ox, oy: oy, fx: fx, fy: fy)
                    .frame(width: cw, height: ch)
                    .clipped()
                    .saturation(0)       // drop the green → neutral line
                    // Light mode: the art is light-on-dark, so invert it to dark-on-light (WhatsApp's
                    // light chat wallpaper). Dark mode uses it as-is.
                    .colorInvert(if: scheme == .light)
                    .opacity(scheme == .dark ? 0.16 : 0.12)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func doodle(sw: CGFloat, sh: CGFloat, ox: CGFloat, oy: CGFloat,
                        fx: CGFloat, fy: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            Image("DoodleBG")
                .resizable()
                .frame(width: sw, height: sh)
                .offset(x: -ox * fx, y: -oy * fy)
                .animation(.easeInOut(duration: 1.2), value: cell)   // slow drift on the 30s tick
        }
    }
}

private extension View {
    /// Apply `.colorInvert()` only when `condition` is true (keeps a single view branch).
    @ViewBuilder func colorInvert(if condition: Bool) -> some View {
        if condition { self.colorInvert() } else { self }
    }
}

extension View {
    /// Screen wallpaper: a random doodle slice in dark mode, the plain app background in light mode.
    func doodleScreenBackground(cell: Int) -> some View {
        background(DoodleWallpaper(cell: cell))
    }
}

// MARK: - Recipe Cover Image Helper

struct RecipeCoverImage: View {
    let urlString: String?
    
    var body: some View {
        if let s = urlString, !s.isEmpty {
            if let img = UIImage(named: s) {
                Image(uiImage: img).resizable()
            } else if let url = Self.remoteURL(from: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        RecipeImagePlaceholder(isBuffering: false, size: 28)
                    case .empty:
                        RecipeImagePlaceholder(isBuffering: true, size: 28)
                    @unknown default:
                        RecipeImagePlaceholder(isBuffering: false, size: 28)
                    }
                }
            } else {
                // Local file: handle both legacy absolute `file://` URLs and direct filenames
                let filename = s.hasPrefix("file://") ? (URL(string: s)?.lastPathComponent ?? s) : s
                let fileUrl = LocalStore.url(filename)
                if let uiImage = UIImage(contentsOfFile: fileUrl.path) {
                    Image(uiImage: uiImage).resizable()
                } else {
                    RecipeImagePlaceholder(isBuffering: false, size: 28)
                }
            }
        } else {
            RecipeImagePlaceholder(isBuffering: false, size: 28)
        }
    }

    /// Resolve a thumbnail string into a loadable remote URL:
    /// absolute http(s) as-is; a server-relative path ("/reels/media/…" from the import backend,
    /// "/media/…" from the media API) gets the right host prepended. Returns nil for local filenames.
    static func remoteURL(from s: String) -> URL? {
        if s.hasPrefix("http://") || s.hasPrefix("https://") { return URL(string: s) }
        guard s.hasPrefix("/") else { return nil }
        let host = s.hasPrefix("/media/") ? "https://api.cravecircle.cc"
                                          : AppConfig.current.apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: host + s)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func toggle(_ on: Bool) {
        UIImpactFeedbackGenerator(style: on ? .medium : .soft).impactOccurred()
    }
}

// MARK: - Pill button

struct PillButton: View {
    enum Kind { case filled, outlined, glass }

    let title: String
    var systemImage: String? = nil
    var kind: Kind = .filled
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .bold)) }
                Text(title).font(AppFont.body(16, weight: .bold))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(border)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private var foreground: Color {
        switch kind {
        case .filled: return AppTheme.onAccent
        case .outlined, .glass: return AppTheme.textPrimary
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .filled: Capsule().fill(AppTheme.accent)
        case .outlined: Capsule().fill(.clear)
        case .glass: Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder private var border: some View {
        if kind == .outlined {
            Capsule().stroke(AppTheme.hairline, lineWidth: 1.5)
        }
    }
}

/// Scale-and-dim press feedback, spring release.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(AppMotion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Glass overlay icon button (over photography)

struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 38
    var label: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label ?? systemImage)
    }
}

// MARK: - Custom lime segmented control

/// Apple-style glassy switch. Same brand tint as the system toggle (never green), but the track and
/// knob are rendered with translucent material so the control reads as frosted glass. Drop-in via
/// `.toggleStyle(GlassToggleStyle())`.
struct GlassToggleStyle: ToggleStyle {
    var onColor: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        let on = configuration.isOn
        return HStack {
            configuration.label
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(onColor.opacity(on ? 0.9 : 0)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .frame(width: 51, height: 31)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .padding(2)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                        .overlay(Circle().fill(.ultraThinMaterial).opacity(0.001)) // keep crisp on glass
                }
                .animation(AppMotion.snappy, value: on)
                .onTapGesture { Haptics.select(); configuration.isOn.toggle() }
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        }
    }
}

struct LimeSegmentedControl: View {
    let segments: [String]
    @Binding var selection: Int
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments.indices, id: \.self) { i in
                let isSelected = selection == i
                Button {
                    Haptics.select()
                    withAnimation(AppMotion.snappy) { selection = i }
                } label: {
                    Text(segments[i])
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if isSelected {
                                Capsule().fill(AppTheme.accent)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.surface, in: Capsule())
    }
}

// MARK: - Checkable rows

/// Ingredient row — radio circle leading, strikethrough + muted when checked.
/// Bold the quantity parts of a cooking line ("1 cup", "½ tbsp", "500g", "2 cloves", "half cup") while
/// leaving the ingredient/instruction words at normal weight. Sets an explicit BOLD font at `size` on the
/// quantity (not `.stronglyEmphasized`, which only nudges to semibold — too subtle in dark mode) so it's a
/// clear regular→bold jump. The rest inherits the view's own `.font`. Works for ingredients and directions.
func boldQuantities(_ text: String, size: CGFloat) -> AttributedString {
    var attr = AttributedString(text)
    let number = #"(?:\d+[\d.,/\-–]*|[¼½¾⅓⅔⅛⅜⅝⅞]|one|two|three|four|five|six|seven|eight|nine|ten|half|quarter)"#
    let unit = #"(?:cups?|tbsps?|tablespoons?|tsps?|teaspoons?|grams?|g|kg|ml|l|oz|ounces?|lbs?|pounds?|cloves?|pinch(?:es)?|cans?|slices?|pieces?|sticks?|bunch(?:es)?|handfuls?)"#
    let pattern = #"(?i)(?<![\p{L}\p{N}])("# + number + #"(?:\s*"# + unit + #"\b)?)"#
    guard let re = try? NSRegularExpression(pattern: pattern) else { return attr }
    let ns = text as NSString
    for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
        guard let sr = Range(m.range(at: 1), in: text) else { continue }
        let lo = text.distance(from: text.startIndex, to: sr.lowerBound)
        let hi = text.distance(from: text.startIndex, to: sr.upperBound)
        let a = attr.index(attr.startIndex, offsetByCharacters: lo)
        let b = attr.index(attr.startIndex, offsetByCharacters: hi)
        attr[a..<b].font = AppFont.body(size, weight: .bold)
    }
    return attr
}

struct IngredientRow: View {
    let text: String
    let checked: Bool
    let toggle: () -> Void

    var body: some View {
        Button {
            Haptics.toggle(!checked)
            toggle()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(checked ? AppTheme.accentInk : AppTheme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                Text(boldQuantities(text, size: 17))
                    .font(AppFont.body(17))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .animation(nil, value: checked)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Parses dense cooking direction text into an action headline, body detail, and glanceable parameter tags (time / temp).
enum DirectionStepParser {
    struct ParsedStep {
        let headline: String
        let detail: String?
        let badges: [String]
    }

    static func parse(_ raw: String) -> ParsedStep {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedStep(headline: "", detail: nil, badges: [])
        }

        var badges: [String] = []

        // Time regex: e.g. "30 minutes", "5-6 min", "6–8 minutes", "1 hour", "2 hrs"
        if let timeRegex = try? NSRegularExpression(pattern: #"\b(\d+[\d\s–\-\.]*(?:mins?|minutes?|hours?|hrs?))\b"#, options: .caseInsensitive) {
            let nsString = trimmed as NSString
            let matches = timeRegex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
            for m in matches.prefix(2) {
                let badge = nsString.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let simplified = badge
                    .replacingOccurrences(of: "minutes", with: "min", options: .caseInsensitive)
                    .replacingOccurrences(of: "minute", with: "min", options: .caseInsensitive)
                    .replacingOccurrences(of: "hours", with: "hr", options: .caseInsensitive)
                    .replacingOccurrences(of: "hour", with: "hr", options: .caseInsensitive)
                if !badges.contains(simplified) {
                    badges.append(simplified)
                }
            }
        }

        // Temp regex: e.g. "350°F (175°C)", "170 degree", "375°F"
        if let tempRegex = try? NSRegularExpression(pattern: #"\b(\d{2,3}\s*°\s*[FC](?:\s*\/\s*\d{2,3}\s*°\s*[FC])?|\d{2,3}\s*degree(?:\s*temp)?)\b"#, options: .caseInsensitive) {
            let nsString = trimmed as NSString
            let matches = tempRegex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
            if let m = matches.first {
                var badge = nsString.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if badge.lowercased().contains("degree") {
                    badge = badge.replacingOccurrences(of: "degree temp", with: "°C", options: .caseInsensitive)
                                 .replacingOccurrences(of: "degree", with: "°C", options: .caseInsensitive)
                }
                if !badges.contains(badge) {
                    badges.append(badge)
                }
            }
        }

        // Separate into headline and detailed instructions
        let sentences = trimmed.components(separatedBy: ". ").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if sentences.count >= 2 {
            let head = sentences[0].trimmingCharacters(in: .whitespaces) + "."
            let rest = sentences.dropFirst().joined(separator: ". ").trimmingCharacters(in: .whitespaces)
            let detail = rest.hasSuffix(".") ? rest : rest + "."
            return ParsedStep(headline: head, detail: detail, badges: badges)
        } else {
            return ParsedStep(headline: trimmed, detail: nil, badges: badges)
        }
    }
}

/// Direction step — action headline, parameter tags (time/temp), clear body text, card layout, trailing checkbox.
struct DirectionRow: View {
    let index: Int
    let text: String
    let checked: Bool
    let toggle: () -> Void

    private var parsed: DirectionStepParser.ParsedStep {
        DirectionStepParser.parse(text)
    }

    var body: some View {
        Button {
            Haptics.toggle(!checked)
            toggle()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Step Number Badge
                Text(String(format: "%02d", index))
                    .font(AppFont.mono(13, weight: .bold))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.accentInk)
                    .frame(width: 32, height: 32)
                    .background(checked ? AnyShapeStyle(AppTheme.hairline) : AnyShapeStyle(AppTheme.accentSoft), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(checked ? Color.clear : AppTheme.accent.opacity(0.35), lineWidth: 0.8))

                // Content Block
                VStack(alignment: .leading, spacing: 6) {
                    // Headline
                    Text(parsed.headline)
                        .font(AppFont.body(16, weight: .bold))
                        .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                        .strikethrough(checked, color: AppTheme.textTertiary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)

                    // Optional Detail
                    if let detail = parsed.detail, !detail.isEmpty {
                        Text(boldQuantities(detail, size: 15))
                            .font(AppFont.body(15))
                            .foregroundStyle(checked ? AppTheme.textTertiary.opacity(0.7) : AppTheme.textSecondary)
                            .strikethrough(checked, color: AppTheme.textTertiary)
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                    }

                    // Badges (Time & Temperature)
                    if !parsed.badges.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(parsed.badges, id: \.self) { badge in
                                HStack(spacing: 4) {
                                    Image(systemName: badge.contains("°") ? "thermometer.medium" : "clock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(badge)
                                        .font(AppFont.label(11, weight: .bold))
                                }
                                .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.accentInk)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(checked ? AnyShapeStyle(AppTheme.hairline) : AnyShapeStyle(AppTheme.accentSoft), in: Capsule())
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Checkbox
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(checked ? AppTheme.accentInk : AppTheme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.top, 4)
            }
            .padding(14)
            .background(checked ? AppTheme.surface.opacity(0.4) : AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(checked ? 0 : 0.03), radius: 6, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meta chip

struct MetaChip: View {
    var systemImage: String? = nil
    let text: String
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
            }
            Text(text).font(AppFont.body(14, weight: .semibold))
        }
        .foregroundStyle(emphasized ? AppTheme.onAccent : AppTheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(emphasized ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(AppTheme.surface), in: Capsule())
    }
}

// MARK: - Creator Avatar Monogram

struct CreatorAvatarView: View {
    let handle: String?
    var size: CGFloat = 36
    var showBorder: Bool = true

    private var initials: String {
        guard let raw = handle?.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "CC"
        }
        let clean = raw.replacingOccurrences(of: "_", with: ".").replacingOccurrences(of: " ", with: ".")
        let parts = clean.split(separator: ".").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(clean.prefix(2)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "3A3835"), Color(hex: "1F1E1B")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(AppFont.serif(size * 0.40, weight: .bold))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.4), lineWidth: showBorder ? 1.2 : 0)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
    }
}

/// Elegant image placeholder that displays an active buffering spinner while loading,
/// or a subtle branded chef hat on error/empty state (never an unrelated dish image).
struct RecipeImagePlaceholder: View {
    var isBuffering: Bool = true
    var size: CGFloat? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "2A2421"), Color(hex: "1C1816")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if isBuffering {
                ProgressView()
                    .tint(AppTheme.accent)
                    .scaleEffect(1.1)
            } else {
                ChefHatLogo(size: size ?? 32)
                    .opacity(0.45)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// System-like interactive pop: drag from the left edge to go back (fullScreenCover has no UINavigationController).
struct LeadingEdgeBackModifier: ViewModifier {
    let onBack: () -> Void
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: max(0, offset))
            .shadow(color: .black.opacity(offset > 0 ? min(0.3, Double(offset / 300)) : 0), radius: 12, x: -4, y: 0)
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: 32)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                if abs(value.translation.width) > abs(value.translation.height) {
                                    offset = max(0, value.translation.width)
                                }
                            }
                            .onEnded { value in
                                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                                let pop = isHorizontal && (value.translation.width > 75 || value.predictedEndTranslation.width > 120)
                                if pop {
                                    Haptics.tap()
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        offset = 1000 // Push offscreen
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        onBack()
                                        offset = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                        offset = 0
                                    }
                                }
                            }
                    )
                    .ignoresSafeArea()
            }
            .onAppear { offset = 0 }
    }
}

extension View {
    func leadingEdgeBack(_ onBack: @escaping () -> Void) -> some View {
        modifier(LeadingEdgeBackModifier(onBack: onBack))
    }
}


struct GuestWallView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.textTertiary)
            
            Text(title)
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text(message)
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            
            Button {
                Haptics.tap()
                environment.signOut() // Goes back to login
            } label: {
                Text("Log In or Sign Up")
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }
}
