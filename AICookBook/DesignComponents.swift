//
//  DesignComponents.swift
//  CraveCircle (AICookBook)
//
//  Reusable Fusion primitives: pill buttons, a custom lime segmented control,
//  checkable rows, glass overlay buttons, chips, and haptics.
//

import SwiftUI
import UIKit
import CryptoKit

// MARK: - Randomized doodle wallpaper

/// Static, faint, full-page food-doodle wallpaper. Both source images are dark-ink-on-white line art,
/// so: LIGHT mode shows the warm (orange) art as-is on cream; DARK mode inverts the art so the lines
/// become light on near-black. `scaledToFill` guarantees full-page coverage (never a half-covered
/// "cut"). Purely decorative, never interactive.
struct DoodleWallpaper: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AppTheme.background   // base (dark in dark mode, cream in light)
            GeometryReader { geo in
                Image(scheme == .dark ? "DoodleDark" : "DoodleLight")
                    .resizable()
                    .scaledToFill()                     // full-page coverage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    // Dark mode: the art is dark-on-white → invert to light-on-dark.
                    .colorInvert(if: scheme == .dark)
                    .opacity(scheme == .dark ? 0.14 : 0.10)
            }
            .blendMode(scheme == .dark ? .screen : .multiply)   // let the base show through cleanly
        }
        .compositingGroup()   // keep the blend inside the wallpaper, not with content behind it
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// View helpers extracted to their own files:
//   colorInvert(if:)        → View+ConditionalInvert.swift
//   doodleScreenBackground() → View+DoodleBackground.swift

// MARK: - Recipe Cover Image Helper

struct RecipeCoverImage: View {
    var urlString: String?
    var recipeId: String? = nil
    var title: String? = nil
    
    init(urlString: String?, recipeId: String? = nil, title: String? = nil) {
        self.urlString = urlString
        self.recipeId = recipeId
        self.title = title
    }
    
    init(recipe: Recipe) {
        self.urlString = recipe.thumbnailUrl
        self.recipeId = recipe.id
        self.title = recipe.title
    }
    
    private var localImage: UIImage? {
        // 1. Check direct filename or relative thumbnail path
        if let s = urlString, !s.isEmpty {
            if s.hasPrefix("thumb-") || !s.contains("://") {
                let filename = s.hasPrefix("file://") ? (URL(string: s)?.lastPathComponent ?? s) : s
                if let img = UIImage(contentsOfFile: LocalStore.url(filename).path) {
                    return img
                }
            } else if s.hasPrefix("file://") {
                let filename = URL(string: s)?.lastPathComponent ?? s
                if let img = UIImage(contentsOfFile: LocalStore.url(filename).path) {
                    return img
                }
            }
        }
        
        // 2. If recipeId provided, check standard on-device thumbnail names
        if let rid = recipeId, !rid.isEmpty {
            for ext in ["jpg", "jpeg", "heic", "png"] {
                let file = LocalStore.url("thumb-\(rid).\(ext)")
                if let img = UIImage(contentsOfFile: file.path) {
                    return img
                }
            }
        }
        
        // 3. Extract recipe ID from urlString if it matches thumb-<id> pattern
        if let s = urlString, let range = s.range(of: "thumb-[^/.]+", options: .regularExpression) {
            let thumbBase = String(s[range])
            for ext in ["jpg", "jpeg", "heic", "png"] {
                let file = LocalStore.url("\(thumbBase).\(ext)")
                if let img = UIImage(contentsOfFile: file.path) {
                    return img
                }
            }
        }
        
        return nil
    }
    
    private var contextHint: String {
        [title, recipeId, urlString].compactMap { $0 }.joined(separator: " ")
    }
    
    var body: some View {
        if let local = localImage {
            // Priority 1: On-device stored cover (0ms latency, 100% offline-ready, immune to CDN expiry)
            Image(uiImage: local).resizable()
        } else if let s = urlString, !s.isEmpty, let bundled = UIImage(named: s) ?? Self.bundledAsset(from: s) {
            // Priority 2: Shipped high-res asset bundled in app (instant, offline)
            Image(uiImage: bundled).resizable()
        } else if let url = Self.remoteURL(from: urlString, recipeId: recipeId) {
            CachedRemoteCover(url: url, fallback: Self.categoryFallback(for: contextHint))
        } else {
            // Priority 4: Category fallback based on title, slug, or cuisine keywords (NEVER black card)
            Image(uiImage: Self.categoryFallback(for: contextHint)).resizable()
        }
    }

    /// Authentic high-res food image fallback for dishes when an exact matching image asset is not yet available
    static func categoryFallback(for raw: String) -> UIImage {
        let base = raw.lowercased()
        
        // Chaat, street food, snacks
        if base.contains("pani_puri") || base.contains("chaat") || base.contains("bhel") || base.contains("vada_pav") || base.contains("tikki") || base.contains("kulcha") || base.contains("samosa") {
            if let img = UIImage(named: "recipe_samosa_chaat") { return img }
        }
        
        // Soups, lentils, broths
        if base.contains("rasam") || base.contains("tadka") || base.contains("dal") || base.contains("sambar") || base.contains("lentil") {
            if let img = UIImage(named: "recipe_dal_tadka") ?? UIImage(named: "recipe_dal_makhani") { return img }
        }
        
        // Rice dishes — spread across distinct plated photos so jeera / curd / plain rice don't share one frame.
        if base.contains("rice") || base.contains("bath") || base.contains("pulihora") || base.contains("biryani") || base.contains("pulao") {
            if let img = pick(from: ["recipe_biryani", "recipe_korean_bibimbap", "recipe_mushroom_risotto", "recipe_chipotle_bowl", "recipe_falafel_bowl", "recipe_thai_basil_chicken"], salt: base) {
                return img
            }
        }
        
        // South Indian crepes & fritters — dosa variants must not all render as masala dosa.
        if base.contains("dosa") || base.contains("vada") || base.contains("appam") || base.contains("uttapam") || base.contains("pesarattu") || base.contains("idli") || base.contains("stew") {
            if let img = pick(from: ["recipe_masala_dosa", "recipe_souffle_pancakes", "recipe_avocado_toast", "recipe_chole_bhature", "recipe_pav_bhaji"], salt: base) {
                return img
            }
        }
        
        // Paneer & rich vegetarian curries
        if base.contains("korma") || base.contains("malai") || base.contains("kofta") || base.contains("shahi") || base.contains("matar_paneer") || base.contains("paneer") {
            if let img = UIImage(named: "recipe_shahi_paneer") ?? UIImage(named: "recipe_paneer_butter_masala") { return img }
        }
        
        // Potato & cauliflower dishes (Dum Aloo, Aloo Gobi, etc.)
        if base.contains("aloo") || base.contains("dum") || base.contains("potato") || base.contains("gobi") {
            if let img = UIImage(named: "recipe_aloo_gobi") { return img }
        }
        
        // Greens & vegetable dishes
        if base.contains("saag") || base.contains("palak") || base.contains("bharta") || base.contains("bhindi") || base.contains("avial") || base.contains("baingan") {
            if let img = UIImage(named: "recipe_palak_paneer") ?? UIImage(named: "recipe_aloo_gobi") { return img }
        }
        
        // Chicken, meat, seafood, rich gravies
        if base.contains("keema") || base.contains("chicken") || base.contains("kadai") || base.contains("meat") || base.contains("vindaloo") || base.contains("curry") || base.contains("jhol") || base.contains("fish") || base.contains("pork") || base.contains("shrimp") || base.contains("chingri") {
            if let img = UIImage(named: "recipe_kadai_chicken") ?? UIImage(named: "recipe_butter_chicken") { return img }
        }
        
        // Beans, chickpeas
        if base.contains("chana") || base.contains("rajma") || base.contains("chole") {
            if let img = UIImage(named: "recipe_chana_masala") ?? UIImage(named: "recipe_rajma_masala") { return img }
        }
        
        // Sweets & desserts
        if base.contains("jamun") || base.contains("cake") || base.contains("dessert") || base.contains("sweet") || base.contains("tiramisu") {
            if let img = UIImage(named: "recipe_gulab_jamun") { return img }
        }
        
        // Pasta & Italian
        if base.contains("pasta") || base.contains("rigatoni") || base.contains("pizza") || base.contains("risotto") {
            if let img = UIImage(named: "recipe_tomato_rigatoni") ?? UIImage(named: "recipe_margherita_pizza") { return img }
        }
        
        // Guaranteed authentic fallback: NEVER nil, NEVER black placeholder card
        return pick(from: ["recipe_aloo_gobi", "recipe_butter_chicken", "recipe_biryani", "recipe_palak_paneer", "recipe_dal_makhani"], salt: base)
            ?? UIImage(named: "recipe_biryani")
            ?? UIImage()
    }

    /// Stable pick so two different dish names in the same family don't share one photo.
    private static func pick(from names: [String], salt: String) -> UIImage? {
        let imgs = names.compactMap { UIImage(named: $0) }
        guard !imgs.isEmpty else { return nil }
        var hash: UInt = 0
        for byte in salt.utf8 { hash = hash &* 31 &+ UInt(byte) }
        return imgs[Int(hash % UInt(imgs.count))]
    }

    /// A shipped image asset matching the thumbnail's filename, if any. Seeded recipes carry a remote
    /// URL like `…/thumbnails/recipe_hot_honey_chicken.jpg`; the basename `recipe_hot_honey_chicken`
    /// is an asset we bundle, so we can render it offline when the host is down. Returns nil for
    /// filenames we don't ship (e.g. raw Instagram CDN URLs from reel imports).
    static func bundledAsset(from s: String) -> UIImage? {
        let base = ((s as NSString).lastPathComponent as NSString).deletingPathExtension
        guard base.hasPrefix("recipe_") else { return nil }   // only our own seeded thumbnails
        return UIImage(named: base)
    }

    /// Resolve a thumbnail string into a loadable remote URL:
    /// Handles full URLs, relative paths, Supabase Storage URLs, and recipe slugs.
    static func remoteURL(from s: String?, recipeId: String? = nil) -> URL? {
        if let s, !s.isEmpty {
            if s.hasPrefix("https://db.cravecircle.cc/storage/") {
                return URL(string: s)
            }
            if s.hasPrefix("http://") || s.hasPrefix("https://") {
                // If it's not an expired fbcdn/instagram CDN URL
                if !s.contains("fbcdn.net") && !s.contains("instagram.") {
                    return URL(string: s)
                }
            }
            if s.hasPrefix("/") {
                let host = s.hasPrefix("/media/") ? "https://api.cravecircle.cc"
                                                  : AppConfig.current.apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return URL(string: host + s)
            }
            if s.hasPrefix("recipe_") {
                let slug = s.replacingOccurrences(of: ".jpg", with: "").replacingOccurrences(of: ".png", with: "")
                return URL(string: "https://db.cravecircle.cc/storage/v1/object/public/recipe-thumbnails/\(slug).jpg")
            }
        }
        
        if let rid = recipeId, rid.hasPrefix("recipe-") {
            let slug = rid.replacingOccurrences(of: "-", with: "_")
            return URL(string: "https://db.cravecircle.cc/storage/v1/object/public/recipe-thumbnails/\(slug).jpg")
        }
        
        return nil
    }
}

// MARK: - Disk-backed cover cache
// AsyncImage only keeps URLCache for the process, and many storage responses are not reusable
// across launches. Covers are written under Caches/cover-cache and shown from disk on the next open.

enum CoverDiskCache {
    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        return cache
    }()

    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cover-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Drop the query string so a refreshed signed URL still matches the file we already saved.
    private static func stableKey(_ url: URL) -> String {
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.query = nil
        parts?.fragment = nil
        let raw = parts?.string ?? url.absoluteString
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private static func file(for url: URL) -> URL {
        directory().appendingPathComponent(stableKey(url) + ".jpg")
    }

    static func memoryImage(for url: URL) -> UIImage? {
        memory.object(forKey: stableKey(url) as NSString)
    }

    static func loadDisk(for url: URL) -> UIImage? {
        let path = file(for: url)
        guard let data = try? Data(contentsOf: path), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: stableKey(url) as NSString)
        return image
    }

    static func download(_ url: URL) async -> UIImage? {
        if let hit = memoryImage(for: url) { return hit }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let image = UIImage(data: data) else { return nil }
        if let jpeg = image.jpegData(compressionQuality: 0.82) {
            try? jpeg.write(to: file(for: url), options: .atomic)
        }
        memory.setObject(image, forKey: stableKey(url) as NSString)
        return image
    }
}

private struct CachedRemoteCover: View {
    let url: URL
    let fallback: UIImage
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                RecipeImagePlaceholder(isBuffering: true, size: 28)
            }
        }
        .task(id: url.absoluteString) {
            if let cached = CoverDiskCache.memoryImage(for: url) {
                image = cached
                return
            }
            let disk = await Task.detached(priority: .userInitiated) {
                CoverDiskCache.loadDisk(for: url)
            }.value
            if let disk {
                image = disk
                return
            }
            if let fresh = await CoverDiskCache.download(url) {
                image = fresh
            } else if image == nil {
                image = fallback
            }
        }
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
    enum Kind { case filled, outlined, glass, surface }

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
        case .outlined, .glass, .surface: return AppTheme.textPrimary
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .filled: Capsule().fill(AppTheme.accent)
        case .outlined: Capsule().fill(.clear)
        case .glass: Capsule().fill(.ultraThinMaterial)
        case .surface: Capsule().fill(AppTheme.surface)   // opaque — hides the wallpaper behind it
        }
    }

    @ViewBuilder private var border: some View {
        if kind == .outlined {
            Capsule().stroke(AppTheme.hairline, lineWidth: 1.5)
        } else if kind == .surface {
            Capsule().stroke(AppTheme.hairline, lineWidth: 1)
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
                LottieView(name: "Flow_4")
                    .frame(width: 28, height: 28)
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

// `leadingEdgeBack(_:)` lives in View+LeadingEdgeBack.swift.


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
