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
    
    /// Decoded local covers. `body` runs again inside scroll `sizeThatFits`; without this,
    /// every pass re-reads the file on the main thread.
    private static let storeCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        return cache
    }()
    private static let storeLock = NSLock()
    private static var missingStoreFiles = Set<String>()
    @State private var loadedLocal: UIImage?

    /// Memory only. Disk and decode happen off the main thread; `body` runs inside scroll layout.
    private var memoryLocalImage: UIImage? {
        for name in Self.localCoverFilenames(urlString: urlString, recipeId: recipeId) {
            if let image = Self.storeCache.object(forKey: name as NSString) { return image }
        }
        return nil
    }

    /// Decode one local cover. Safe off the main thread. A miss is remembered so layout never stats it again.
    /// A cover file written after the card already looked and found nothing.
    static func noteCoverReady(_ filename: String) {
        storeLock.lock()
        missingStoreFiles.remove(filename)
        storeLock.unlock()
        storeCache.removeObject(forKey: filename as NSString)
    }

    static func loadStoreImage(named filename: String) -> UIImage? {
        let key = filename as NSString
        if let hit = storeCache.object(forKey: key) { return hit }
        storeLock.lock()
        let knownMissing = missingStoreFiles.contains(filename)
        storeLock.unlock()
        if knownMissing { return nil }
        let url = LocalStore.url(filename)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            storeLock.lock()
            missingStoreFiles.insert(filename)
            storeLock.unlock()
            return nil
        }
        storeCache.setObject(image, forKey: key)
        return image
    }

    /// Names worth opening under LocalStore. Bundled asset names (`recipe_hot_honey_chicken`)
    /// and remote URLs are not files. `UIImage(contentsOfFile:)` on those misses still walks
    /// `@2x`/`@3x` variants with `faccessat` during layout — the 426ms home-feed hitch.
    static func localCoverFilenames(urlString: String?, recipeId: String?) -> [String] {
        var names: [String] = []
        if let file = localCoverFilename(urlString) {
            names.append(file)
        }
        // Writers that save a frame also set thumbnailUrl to `thumb-<id>.<ext>`. Probing four
        // extensions for every card that already has a cover string is the layout hang.
        if (urlString ?? "").isEmpty, let rid = recipeId, !rid.isEmpty {
            names.append(contentsOf: Self.thumbExtensions.map { "thumb-\(rid).\($0)" })
        }
        if let s = urlString, s.contains("thumb-"),
           let range = s.range(of: "thumb-[^/.]+", options: .regularExpression) {
            let thumbBase = String(s[range])
            if !names.contains(where: { $0.hasPrefix(thumbBase) }) {
                names.append(contentsOf: Self.thumbExtensions.map { "\(thumbBase).\($0)" })
            }
        }
        return names
    }

    static func localCoverFilename(_ urlString: String?) -> String? {
        guard let s = urlString, !s.isEmpty else { return nil }
        if s.hasPrefix("file://") {
            let name = URL(string: s)?.lastPathComponent ?? ""
            return name.isEmpty ? nil : name
        }
        if s.contains("://") || s.hasPrefix("/") { return nil }
        if s.hasPrefix("thumb-") { return s }
        let ext = (s as NSString).pathExtension.lowercased()
        if Self.thumbExtensions.contains(ext) { return s }
        return nil
    }

    private static let thumbExtensions = ["jpg", "jpeg", "heic", "png"]

    private var contextHint: String {
        [title, recipeId, urlString].compactMap { $0 }.joined(separator: " ")
    }
    
    var body: some View {
        let local = memoryLocalImage ?? loadedLocal
        Group {
            if let local {
                Image(uiImage: local).resizable()
            } else if let s = urlString, !s.isEmpty, let bundled = UIImage(named: s) ?? Self.bundledAsset(from: s) {
                Image(uiImage: bundled).resizable()
            } else if let url = Self.remoteURL(from: urlString, recipeId: recipeId) {
                CachedRemoteCover(url: url, fallback: Self.categoryFallback(for: contextHint))
            } else {
                Image(uiImage: Self.categoryFallback(for: contextHint)).resizable()
            }
        }
        .task(id: "\(urlString ?? "")|\(recipeId ?? "")") {
            guard memoryLocalImage == nil else { return }
            let names = Self.localCoverFilenames(urlString: urlString, recipeId: recipeId)
            guard !names.isEmpty else { return }
            let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                for name in names {
                    if let image = RecipeCoverImage.loadStoreImage(named: name) { return image }
                }
                return nil
            }.value
            if let image { loadedLocal = image }
        }
    }

    private static let fallbackCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        return cache
    }()

    /// One bundled asset for this dish. Layout must not open every photo in the family.
    static func fallbackAssetName(for raw: String) -> String {
        let base = raw.lowercased()
        if base.contains("pani_puri") || base.contains("chaat") || base.contains("bhel") || base.contains("vada_pav") || base.contains("tikki") || base.contains("kulcha") || base.contains("samosa") {
            return "recipe_samosa_chaat"
        }
        if base.contains("rasam") || base.contains("tadka") || base.contains("dal") || base.contains("sambar") || base.contains("lentil") {
            return "recipe_dal_tadka"
        }
        if base.contains("rice") || base.contains("bath") || base.contains("pulihora") || base.contains("biryani") || base.contains("pulao") {
            return pickName(from: ["recipe_biryani", "recipe_korean_bibimbap", "recipe_mushroom_risotto", "recipe_chipotle_bowl", "recipe_falafel_bowl", "recipe_thai_basil_chicken"], salt: base)
        }
        if base.contains("dosa") || base.contains("vada") || base.contains("appam") || base.contains("uttapam") || base.contains("pesarattu") || base.contains("idli") || base.contains("stew") {
            return pickName(from: ["recipe_masala_dosa", "recipe_souffle_pancakes", "recipe_avocado_toast", "recipe_chole_bhature", "recipe_pav_bhaji"], salt: base)
        }
        if base.contains("korma") || base.contains("malai") || base.contains("kofta") || base.contains("shahi") || base.contains("matar_paneer") || base.contains("paneer") {
            return "recipe_shahi_paneer"
        }
        if base.contains("aloo") || base.contains("dum") || base.contains("potato") || base.contains("gobi") {
            return "recipe_aloo_gobi"
        }
        if base.contains("saag") || base.contains("palak") || base.contains("bharta") || base.contains("bhindi") || base.contains("avial") || base.contains("baingan") {
            return "recipe_palak_paneer"
        }
        if base.contains("keema") || base.contains("chicken") || base.contains("kadai") || base.contains("meat") || base.contains("vindaloo") || base.contains("curry") || base.contains("jhol") || base.contains("fish") || base.contains("pork") || base.contains("shrimp") || base.contains("chingri") {
            return "recipe_kadai_chicken"
        }
        if base.contains("chana") || base.contains("rajma") || base.contains("chole") {
            return "recipe_chana_masala"
        }
        if base.contains("jamun") || base.contains("cake") || base.contains("dessert") || base.contains("sweet") || base.contains("tiramisu") {
            return "recipe_gulab_jamun"
        }
        if base.contains("pasta") || base.contains("rigatoni") || base.contains("pizza") || base.contains("risotto") {
            return "recipe_tomato_rigatoni"
        }
        return pickName(from: ["recipe_aloo_gobi", "recipe_butter_chicken", "recipe_biryani", "recipe_palak_paneer", "recipe_dal_makhani"], salt: base)
    }

    /// Authentic high-res food image fallback for dishes when an exact matching image asset is not yet available
    static func categoryFallback(for raw: String) -> UIImage {
        let key = raw.lowercased() as NSString
        if let hit = fallbackCache.object(forKey: key) { return hit }
        let name = fallbackAssetName(for: raw)
        let image = UIImage(named: name) ?? UIImage(named: "recipe_biryani") ?? UIImage()
        fallbackCache.setObject(image, forKey: key)
        return image
    }

    /// Stable pick so two different dish names in the same family don't share one photo.
    /// Chooses the name only. Opening every photo in the list was a main-thread hitch while scrolling.
    private static func pickName(from names: [String], salt: String) -> String {
        guard !names.isEmpty else { return "recipe_biryani" }
        var hash: UInt = 0
        for byte in salt.utf8 { hash = hash &* 31 &+ UInt(byte) }
        return names[Int(hash % UInt(names.count))]
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
                // Instagram's own cover is the dish the person shared. Load it; don't swap in a
                // bundled photo just because the host is fbcdn.
                return URL(string: s)
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
        // Instagram's CDN refuses a bare request. A browser agent is enough to fetch the cover.
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
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

/// Insert or remove one checklist value. Callers share this so ingredient and step checks
/// don't each grow their own toggle. Grocery checks stay on `AppEnvironment.toggleGroceryItemLocal`.
func toggleChecklistItem<T: Hashable>(_ set: inout Set<T>, _ value: T) {
    let willCheck = !set.contains(value)
    Haptics.toggle(willCheck)
    if willCheck { set.insert(value) } else { set.remove(value) }
}

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

/// Ingredient row: the amount comes first, in bold, then the name.
func ingredientLine(_ text: String, size: CGFloat) -> AttributedString {
    let parts = IngredientListFormat.displayParts(text)
    guard !parts.amount.isEmpty else { return AttributedString(parts.name) }
    let combined = parts.name.isEmpty ? parts.amount : parts.amount + " " + parts.name
    var attr = AttributedString(combined)
    let hi = attr.index(attr.startIndex, offsetByCharacters: parts.amount.count)
    attr[attr.startIndex..<hi].font = AppFont.body(size, weight: .bold)
    return attr
}

/// One checklist row: circle / checkmark, at least 44pt, Checked/Unchecked.
/// Plain rows are grocery and cook lists. Ingredient rows may lead with the check.
/// Pass `stepNumber` for a direction card (badge, headline, detail, clock chip) — same toggle, trailing circle.
struct ChecklistRow: View {
    var title: AttributedString
    var subtitle: AttributedString? = nil
    var trailing: String? = nil
    var minHeight: CGFloat = 44
    var stepNumber: Int? = nil
    var chips: [String] = []
    var checkLeading: Bool = false
    let checked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if stepNumber != nil {
                cardLabel
            } else {
                plainLabel
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
        .accessibilityValue(checked ? "Checked" : "Unchecked")
    }

    private var plainLabel: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            if checkLeading { checkImage }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(17))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .multilineTextAlignment(.leading)
                if let subtitle, !subtitle.characters.isEmpty {
                    Text(subtitle)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .strikethrough(checked, color: AppTheme.textTertiary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .monospacedDigit()
            }

            if !checkLeading { checkImage }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var cardLabel: some View {
        HStack(alignment: .top, spacing: 14) {
            if let stepNumber {
                Text(String(format: "%02d", stepNumber))
                    .font(AppFont.mono(13, weight: .bold))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.accentInk)
                    .frame(width: 32, height: 32)
                    .background(
                        checked ? AnyShapeStyle(AppTheme.hairline) : AnyShapeStyle(AppTheme.accentSoft),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(checked ? Color.clear : AppTheme.accent.opacity(0.35), lineWidth: 0.8)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)

                if let subtitle, !subtitle.characters.isEmpty {
                    Text(subtitle)
                        .font(AppFont.body(15))
                        .foregroundStyle(checked ? AppTheme.textTertiary.opacity(0.7) : AppTheme.textSecondary)
                        .strikethrough(checked, color: AppTheme.textTertiary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                }

                if !chips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(chips, id: \.self) { chip in
                            HStack(spacing: 4) {
                                Image(systemName: chip.contains("°") ? "thermometer.medium" : "clock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(chip)
                                    .font(AppFont.label(11, weight: .bold))
                            }
                            .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.accentInk)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                checked ? AnyShapeStyle(AppTheme.hairline) : AnyShapeStyle(AppTheme.accentSoft),
                                in: Capsule()
                            )
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            checkImage
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(
            checked ? AppTheme.surface.opacity(0.4) : AppTheme.surface,
            in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(checked ? 0 : 0.03), radius: 6, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }

    private var checkImage: some View {
        Image(systemName: checked ? "checkmark.circle" : "circle")
            .font(AppFont.body(22))
            .foregroundStyle(checked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Reports the enclosing list's content height so an inset-grouped list can sit in a parent scroll view.
    func readChecklistHeight(_ height: Binding<CGFloat>) -> some View {
        background {
            ChecklistScrollProbe { next in
                guard next > 1, abs(height.wrappedValue - next) > 0.5 else { return }
                height.wrappedValue = next
            }
        }
    }
}

/// ponytail: walks up to the list's collection view because `List` does not self-size inside a `ScrollView`.
/// Upgrade path: drop this when the checklist is the screen's own scroller (cook mode already is).
private struct ChecklistScrollProbe: UIViewRepresentable {
    var onHeight: (CGFloat) -> Void

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onHeight = onHeight
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        uiView.onHeight = onHeight
    }

    final class Probe: UIView {
        var onHeight: ((CGFloat) -> Void)?
        private var last: CGFloat = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let collection = sequence(first: superview, next: { $0?.superview }).compactMap({ $0 as? UICollectionView }).first else { return }
            let content = collection.collectionViewLayout.collectionViewContentSize.height
            guard content > 1, abs(content - last) > 0.5 else { return }
            last = content
            let report = onHeight
            DispatchQueue.main.async { report?(content) }
        }
    }
}

/// Parses dense cooking direction text into an action headline, body detail, and glanceable parameter tags (time / temp).
enum DirectionStepParser {
    struct ParsedStep {
        let headline: String
        let detail: String?
        let badges: [String]
    }

    /// One direction, broken into short lines. No stacked sentences, no trailing period.
    static func shortLines(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var pieces = splitClauses(trimmed).flatMap(splitThen)
        pieces = pieces.flatMap { splitIfLong($0) }
        let lines = pieces.map(tidyLine).filter { $0.count >= 2 }
        return lines.isEmpty ? [tidyLine(trimmed)].filter { !$0.isEmpty } : lines
    }

    private static func splitClauses(_ text: String) -> [String] {
        var out: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if ".!?".contains(c), next == " " || next == "\n" || i == chars.count - 1 {
                let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { out.append(piece) }
                current = ""
            } else if c == ";" || c == "\n" {
                let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { out.append(piece) }
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { out.append(tail) }
        return out
    }

    private static func splitThen(_ text: String) -> [String] {
        let parts = text.components(separatedBy: " then ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.count > 1 ? parts : [text]
    }

    /// A long line with commas becomes separate actions. A one-word scrap joins the next piece.
    private static func splitIfLong(_ text: String) -> [String] {
        let words = text.split(separator: " ")
        guard words.count > 14, text.contains(",") else { return [text] }
        var parts = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var merged: [String] = []
        var i = 0
        while i < parts.count {
            if parts[i].split(separator: " ").count < 3, i + 1 < parts.count {
                parts[i + 1] = parts[i] + " " + parts[i + 1]
            } else if parts[i].split(separator: " ").count < 3, let last = merged.popLast() {
                merged.append(last + " " + parts[i])
            } else {
                merged.append(parts[i])
            }
            i += 1
        }
        return merged.isEmpty ? [text] : merged
    }

    private static func tidyLine(_ text: String) -> String {
        var t = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
        let fillers = ["and ", "then ", "thoroughly ", "gently ", "carefully ", "immediately ", "meanwhile ", "next ", "now ", "finally "]
        var lower = t.lowercased()
        var changed = true
        while changed {
            changed = false
            for filler in fillers where lower.hasPrefix(filler) {
                t = String(t.dropFirst(filler.count))
                lower = t.lowercased()
                changed = true
            }
        }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return "" }
        return first.uppercased() + t.dropFirst()
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
                // Clear the paywall flag BEFORE signing out — otherwise the sheet stays bound
                // to true and will re-present itself on MainTabView after the next sign-in,
                // which is exactly what the user kept seeing ("Sign in to continue" after a
                // successful login).
                environment.showGuestPaywall = false
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
