import Foundation

/// App account role. Consumers browse; approved creators and admins can publish to the feed.
enum AccountRole: String, Codable {
    case user
    case creator
    case admin

    /// Admins publish anything; approved creators publish their own recipes to the public feed.
    /// A plain user can save and import for themselves, not publish.
    var canPublish: Bool { self == .admin || self == .creator }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AccountRole(rawValue: raw) ?? .user
    }
}

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String?
    var fullName: String?
    var avatarUrl: String?
    var role: AccountRole
    /// Short bio shown on the creator profile. Optional — a plain user can leave it blank.
    var bio: String? = nil
    /// Public social links the user chooses to show. Each is a full URL; nil / empty hides the icon.
    var instagramUrl: String? = nil
    var tiktokUrl: String? = nil
    var youtubeUrl: String? = nil
    var facebookUrl: String? = nil
    var pinterestUrl: String? = nil
    /// Admin-granted blue tick. UI shows the checkmark badge only when this is true.
    var verified: Bool = false
    /// Set the first time this account finishes onboarding. Non-nil → skip the flow on any
    /// fresh install this id signs into. Server-authoritative so it syncs across devices.
    var onboardedAt: Date? = nil

    var canPublish: Bool { role.canPublish }

    init(id: String, username: String? = nil, fullName: String? = nil, avatarUrl: String? = nil,
         role: AccountRole = .user, bio: String? = nil,
         instagramUrl: String? = nil, tiktokUrl: String? = nil,
         youtubeUrl: String? = nil, facebookUrl: String? = nil,
         pinterestUrl: String? = nil, verified: Bool = false, onboardedAt: Date? = nil) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.role = role
        self.bio = bio
        self.instagramUrl = instagramUrl
        self.tiktokUrl = tiktokUrl
        self.youtubeUrl = youtubeUrl
        self.facebookUrl = facebookUrl
        self.pinterestUrl = pinterestUrl
        self.verified = verified
        self.onboardedAt = onboardedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        role = try c.decodeIfPresent(AccountRole.self, forKey: .role) ?? .user
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        instagramUrl = try c.decodeIfPresent(String.self, forKey: .instagramUrl)
        tiktokUrl = try c.decodeIfPresent(String.self, forKey: .tiktokUrl)
        youtubeUrl = try c.decodeIfPresent(String.self, forKey: .youtubeUrl)
        facebookUrl = try c.decodeIfPresent(String.self, forKey: .facebookUrl)
        pinterestUrl = try c.decodeIfPresent(String.self, forKey: .pinterestUrl)
        verified = (try c.decodeIfPresent(Bool.self, forKey: .verified)) ?? false
        onboardedAt = try c.decodeIfPresent(Date.self, forKey: .onboardedAt)
    }
}

enum ImportStatus: String, Codable {
    case queued
    case downloading
    case preparing
    case transcribing
    case extracting
    case done
    case error

    var displayLabel: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading reel"
        case .preparing: return "Getting ready to listen"
        case .transcribing: return "Transcribing audio"
        case .extracting: return "Extracting recipe"
        case .done: return "Done"
        case .error: return "Failed"
        }
    }

    var isTerminal: Bool {
        self == .done || self == .error
    }
}

struct ImportSubmitResponse: Codable {
    let jobId: String
    let poll: String?
    let status: ImportStatus?
}

struct ImportJob: Codable, Identifiable {
    let id: String
    let status: ImportStatus
    let errorMessage: String?
    let recipeId: String?
}

enum RecipeVisibility: String, Codable {
    case everyone
    case followers
}

/// A user's request to become a creator — submitted with their social handle for verification,
/// then approved/rejected by an admin.
struct CreatorRequest: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    var socialPlatform: String
    var socialHandle: String
    var socialUrl: String?
    var note: String?
    var status: String            // pending / approved / rejected
    let createdAt: Date
}

struct SharedRecipeRecord: Codable, Identifiable, Hashable {
    let id: String
    let recipeId: String
    let fromUserId: String
    let toUserId: String
    let createdAt: Date
    let channel: String?
    var recipeTitle: String?        // carried on the share so the recipient always sees the recipe
    var recipeThumbnail: String?
}

struct Recipe: Codable, Identifiable, Hashable {
    let id: String
    var ownerId: String
    var title: String
    var description: String?
    var prepTime: String?
    var cookTime: String?
    var servings: Int?
    var ingredients: [IngredientGroup]
    var directions: [DirectionStep]
    var thumbnailUrl: String?
    var galleryUrls: [String]? = nil   // up to 6 dish photos; the cover stays `thumbnailUrl` (= first)
    var ownerUsername: String?
    var sourceLanguage: String?   // BCP-47 code of the reel's original language, if translated
    var nutrition: RecipeNutrition?   // per-serving; server-computed from ingredients, else estimated
    var sourceUrl: String?        // URL of the source Instagram / TikTok reel
    var visibility: RecipeVisibility = .everyone

    /// True only when this recipe was imported from a social reel (Instagram / TikTok / YouTube / Facebook).
    var isImportedFromSocial: Bool { Self.isSocialImportURL(sourceUrl) }

    /// Every image for the detail gallery: the extra gallery photos if present, else just the cover.
    var galleryImages: [String] {
        let g = (galleryUrls ?? []).filter { !$0.isEmpty }
        if !g.isEmpty { return g }
        if let t = thumbnailUrl, !t.isEmpty { return [t] }
        return []
    }

    var reelUrl: URL {
        if let sourceUrl, let url = URL(string: sourceUrl) {
            return url
        }
        let cleanHandle = ownerUsername?.replacingOccurrences(of: "@", with: "") ?? "cravecircle"
        return URL(string: "https://www.instagram.com/\(cleanHandle)/") ?? URL(string: "https://www.instagram.com/reels/")!
    }

    /// Header duration is cook time only. `prepTime` stays on the model so older saves still decode,
    /// but it is never added or shown. Free-form cook values ("15 min", "1 hr 10 min") are re-formatted.
    var totalTimeText: String? {
        guard let cook = cookTime?.trimmingCharacters(in: .whitespacesAndNewlines), !cook.isEmpty else { return nil }
        if let mins = Recipe.minutes(from: cook) { return Recipe.formatMinutes(mins) }
        return cook
    }

    /// Minutes parsed from a free-form duration, or nil if it holds no number. "2 hr 5 min" → 125.
    static func minutes(from text: String?) -> Int? {
        guard let t = text?.lowercased() else { return nil }
        func firstInt(unit: String) -> Int? {
            guard let re = try? NSRegularExpression(pattern: "(\\d+)\\s*" + unit),
                  let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
                  let r = Range(m.range(at: 1), in: t) else { return nil }
            return Int(t[r])
        }
        let h = firstInt(unit: "h"), m = firstInt(unit: "m")
        guard h != nil || m != nil else { return nil }
        return (h ?? 0) * 60 + (m ?? 0)
    }

    static func formatMinutes(_ m: Int) -> String {
        guard m >= 60 else { return "\(m) min" }
        let h = m / 60, rem = m % 60
        return rem == 0 ? "\(h) hr" : "\(h) hr \(rem) min"
    }

    static func isSocialImportURL(_ raw: String?) -> Bool {
        guard let raw, let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host?.lowercased()
        else { return false }
        let social: [String] = ["instagram.com", "tiktok.com", "youtube.com", "youtu.be", "facebook.com", "fb.watch"]
        return social.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    /// A food-blog page saved from the in-app browser. Stays on this phone, like a social import.
    static func isWebImportURL(_ raw: String?) -> Bool {
        guard let raw, let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty
        else { return false }
        if host == "cravecircle.cc" || host.hasSuffix(".cravecircle.cc") { return false }
        return !isSocialImportURL(raw)
    }

    var staysOnThisPhone: Bool { Self.isSocialImportURL(sourceUrl) || Self.isWebImportURL(sourceUrl) }

    /// Written in the app by this account. A web page or someone else's reel is not created.
    func wasWrittenHere(by username: String?) -> Bool {
        if staysOnThisPhone || id.hasPrefix("web-") { return false }
        let handle = ownerUsername?.replacingOccurrences(of: "@", with: "").lowercased() ?? ""
        if handle.isEmpty || handle == "you" { return true }
        let mine = username?.replacingOccurrences(of: "@", with: "").lowercased() ?? ""
        return !mine.isEmpty && handle == mine
    }
}

struct IngredientGroup: Codable, Hashable {
    var groupName: String?
    var items: [String]

    init(groupName: String?, items: [String]) {
        let cleaned = IngredientListFormat.normalize(groupName: groupName, items: items)
        self.groupName = cleaned.groupName
        self.items = cleaned.items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let name = try c.decodeIfPresent(String.self, forKey: .groupName)
        let items = try c.decodeIfPresent([String].self, forKey: .items) ?? []
        self.init(groupName: name, items: items)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(groupName, forKey: .groupName)
        try c.encode(items, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey { case groupName, items }
}

/// Drops the parenthetical caption-tag block creators paste under a recipe.
/// A real note such as "(optional)" or "(finely chopped)" stays on its ingredient.
enum IngredientListFormat {
    private static let socialTokens = ["recipe", "reel", "viral", "blogger", "foodporn", "shorts", "foodie"]

    static func normalize(groupName: String?, items: [String]) -> (groupName: String?, items: [String]) {
        let name = groupName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let keptName = (name?.isEmpty == true || (name != nil && isTagDump(name!))) ? nil : name
        let rows = items.compactMap { cleanedItem($0) }
        return (keptName, rows)
    }

    /// Amount and name for one ingredient row. "Chickpeas / kabuli chana — 1¼ cups dried (250g)"
    /// reads amount-then-name. A line that already starts with the amount ("600g chicken") stays that way.
    /// "(250g)" stays on the amount. "(optional)" and "(finely chopped)" stay on the name.
    struct DisplayParts: Equatable {
        var amount: String
        var name: String
        /// Stored as "name — amount". The amount is the whole right-hand side, including "(250g)".
        var nameDashAmount: Bool = false
    }

    /// Drop blog asides so a line can be cooked from. A weight such as "(30 grams)" stays. "((adjust to taste))" goes.
    static func cookLine(_ raw: String) -> String {
        var s = raw
        let inner = #"\(([^()]*)\)"#
        var guardrail = 0
        while guardrail < 12, let regex = try? NSRegularExpression(pattern: inner) {
            guardrail += 1
            let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            if matches.isEmpty { break }
            var changed = false
            for match in matches.reversed() {
                guard let span = Range(match.range, in: s), let body = Range(match.range(at: 1), in: s) else { continue }
                let kept = measurement(String(s[body])).map { "(\($0))" } ?? ""
                let original = String(s[span])
                guard kept != original else { continue }
                s.replaceSubrange(span, with: kept)
                changed = true
            }
            if !changed { break }
        }
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func measurement(_ inner: String) -> String? {
        let t = inner.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let regex = try? NSRegularExpression(pattern: #"^(\d+(?:\.\d+)?(?:\s*(?:to|-|–)\s*\d+(?:\.\d+)?)?)\s*(grams?|g|ml|oz|kg)$"#),
              let match = regex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              match.numberOfRanges > 2,
              let number = Range(match.range(at: 1), in: t),
              let unit = Range(match.range(at: 2), in: t) else { return nil }
        let name = t[unit].hasPrefix("gram") ? "g" : String(t[unit])
        return "\(t[number]) \(name)"
    }

    static func displayParts(_ raw: String) -> DisplayParts {
        let line = cookLine(raw)
        if let flipped = nameThenAmount(line) {
            return DisplayParts(amount: flipped.amount, name: flipped.name, nameDashAmount: true)
        }
        let leading = GrocerySort.splitQuantity(line)
        if !leading.qty.isEmpty { return DisplayParts(amount: leading.qty, name: leading.name) }
        return DisplayParts(amount: "", name: line)
    }

    /// Scale a "name — amount" line by its amount. Other lines stay on the leading-quantity scaler.
    static func scaledLine(_ raw: String, from base: Int, to target: Int) -> String {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard base != target, let flipped = nameThenAmount(line) else {
            return IngredientScaler.scale(text: raw, from: base, to: target)
        }
        let amount = IngredientScaler.scale(text: flipped.amount, from: base, to: target)
        return "\(flipped.name) — \(amount)"
    }

    /// ponytail: the rightmost spaced dash whose right side starts with a quantity.
    /// A glued pair ("methi - 1 tsp and hing — 1 pinch") keeps the left item inside the name.
    /// Upgrade path: split once per dash that introduces its own quantity.
    private static func nameThenAmount(_ line: String) -> DisplayParts? {
        let separators = [" — ", " – ", " - "]
        var best: (name: String, amount: String, at: String.Index)?
        for sep in separators {
            var search = line.startIndex
            while let range = line.range(of: sep, range: search..<line.endIndex) {
                let left = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let right = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !left.isEmpty, !right.isEmpty,
                   !startsWithQuantity(left), startsWithQuantity(right),
                   best == nil || range.lowerBound >= best!.at {
                    best = (String(left), String(right), range.lowerBound)
                }
                search = range.upperBound
            }
        }
        guard let best else { return nil }
        return DisplayParts(amount: best.amount, name: best.name, nameDashAmount: true)
    }

    private static func startsWithQuantity(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        if first.isNumber { return true }
        let word = s.prefix { $0.isLetter }.lowercased()
        return ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "half", "quarter"].contains(word)
    }

    /// nil when the whole row is a tag dump. Otherwise the ingredient, with a trailing tag block removed.
    static func cleanedItem(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return raw }
        if isTagDump(trimmed) { return nil }
        let stripped = strippingTrailingTagDump(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.isEmpty || isTagDump(stripped) { return nil }
        return stripped
    }

    /// A caption tag dump: a comma-list of social tokens, a long one-word tag run, or a #hashtag line.
    /// Short kitchen notes are not dumps.
    static func isTagDump(_ raw: String) -> Bool {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.filter({ $0 == "#" }).count >= 2 { return true }
        let wrapped = line.hasPrefix("(") && line.hasSuffix(")")
        let body = wrapped
            ? String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            : line
        let parts = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // A real ingredient has a space ("1 onion, chopped", "Chopped coriander (...)").
        // Tag dumps are a comma-list of single smashed words.
        let single = parts.filter { !$0.contains(" ") && $0.rangeOfCharacter(from: .decimalDigits) == nil }
        guard !parts.isEmpty, single.count == parts.count else { return false }
        let hits = parts.filter { part in
            let lower = part.lowercased()
            return socialTokens.contains { lower.contains($0) }
        }.count
        if hits >= 2 && parts.count >= 4 { return true }
        return parts.count >= 8 && (wrapped || hits >= 1)
    }

    private static func strippingTrailingTagDump(_ line: String) -> String {
        guard line.hasSuffix(")"), let open = line.lastIndex(of: "(") else { return line }
        let inner = line[line.index(after: open)..<line.index(before: line.endIndex)]
        guard isTagDump("(\(inner))") else { return line }
        return String(line[..<open]).trimmingCharacters(in: CharacterSet(charactersIn: " -–—,;"))
    }
}

/// One short line under the title. Seeded recipes already have one. An import often only has
/// "Extracted from @…" or nothing, so the page says what the dish is made with.
enum DishBlurb {
    static func line(title: String, stored: String?, items: [String]) -> String? {
        let kept = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !kept.isEmpty, !isPlaceholder(kept) { return kept }
        let names = items.compactMap { readableName($0, title: title) }.reduce(into: [String]()) { acc, name in
            if acc.count < 3, !acc.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                acc.append(name)
            }
        }
        guard !names.isEmpty else { return nil }
        switch names.count {
        case 1: return "Made with \(names[0])."
        case 2: return "Made with \(names[0]) and \(names[1])."
        default: return "Made with \(names[0]), \(names[1]), and \(names[2])."
        }
    }

    static func isPlaceholder(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("extracted from @") || lower.hasPrefix("freshly extracted")
    }

    private static func readableName(_ raw: String, title: String) -> String? {
        let parts = IngredientListFormat.displayParts(raw)
        var name = parts.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let paren = name.firstIndex(of: "(") {
            name = String(name[..<paren])
        }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " -–—,;"))
        guard name.count >= 2, name.caseInsensitiveCompare(title) != .orderedSame else { return nil }
        return name
    }
}

struct GroceryItem: Codable, Identifiable, Equatable {
    let id: String
    let ingredientName: String
    var checked: Bool
    var recipeName: String? = nil   // the dish this came from; nil = added by hand. Groups the list by dish.
}

struct DirectionStep: Codable, Hashable {
    var stepIndex: Int
    var text: String
}


// MARK: - Social & Circle Models

struct FriendItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var username: String
    var bio: String?
    var recipesCount: Int = 0
    var avatarAsset: String? = nil
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        let clean = username.replacingOccurrences(of: "@", with: "")
        return String(clean.prefix(2)).uppercased()
    }

    static let samples: [FriendItem] = [
        .init(id: UUID(), name: "Nada Al-Hassan", username: "@nada_dl", bio: "Gourmet burger enthusiast & recipe creator", recipesCount: 8, avatarAsset: "recipe_hot_honey_chicken"),
        .init(id: UUID(), name: "Aditya Gupta", username: "@Aditya.Gupta", bio: "Meal prep master & macro-friendly cooking", recipesCount: 12, avatarAsset: "recipe_chipotle_bowl"),
        .init(id: UUID(), name: "Kristy Graver", username: "@Kristy.Graver", bio: "Coastal comfort & rustic seafood kitchen", recipesCount: 6, avatarAsset: "recipe_tuscan_salmon"),
        .init(id: UUID(), name: "Dev Sharma", username: "@deveats", bio: "Air fryer experiments & street food spins", recipesCount: 15, avatarAsset: "recipe_korean_wings"),
        .init(id: UUID(), name: "Priya Menon", username: "@priyacooks", bio: "Plant-forward fresh & vibrant greens", recipesCount: 9, avatarAsset: "recipe_green_pasta")
    ]
}

struct FriendRequestItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var username: String
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        let clean = username.replacingOccurrences(of: "@", with: "")
        return String(clean.prefix(2)).uppercased()
    }

    static let incoming: [FriendRequestItem] = [
        .init(id: UUID(), name: "Priya Menon", username: "@priyacooks"),
        .init(id: UUID(), name: "Dev Sharma", username: "@deveats"),
        .init(id: UUID(), name: "Zaatar & Zeal", username: "@zaatarandzeal")
    ]
    static let outgoing: [FriendRequestItem] = [
        .init(id: UUID(), name: "Aisha Khan", username: "@aishaskitchen"),
        .init(id: UUID(), name: "Sanjeev Kapoor", username: "@Sanjeev.Kapoor")
    ]
    static let incomingSamples: [FriendRequestItem] = incoming
    static let outgoingSamples: [FriendRequestItem] = outgoing
}

struct CollectionItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var count: Int
    var shared: Bool
    var imageName: String
    var recipeIds: [String] = []

    static let owned: [CollectionItem] = [
        .init(name: "High Protein Meal Prep", count: 5, shared: false, imageName: "recipe_chipotle_bowl", recipeIds: ["recipe-chipotle-burrito-bowl", "recipe-hot-honey-chicken", "recipe-spicy-paneer-wrap"]),
        .init(name: "Weeknight Dinners", count: 8, shared: false, imageName: "recipe_tuscan_salmon", recipeIds: ["recipe-tuscan-salmon", "recipe-tomato-rigatoni", "recipe-butter-chicken"]),
        .init(name: "15-Minute Quick Fixes", count: 6, shared: false, imageName: "recipe_tomato_rigatoni", recipeIds: ["recipe-tomato-rigatoni", "recipe-green-goddess-pasta", "recipe-spicy-paneer-wrap"]),
        .init(name: "Weekend Brunch & Bakes", count: 4, shared: false, imageName: "recipe_souffle_pancakes", recipeIds: ["recipe-souffle-pancakes", "recipe-shakshuka"]),
        .init(name: "Air Fryer Staples", count: 5, shared: false, imageName: "recipe_korean_wings", recipeIds: ["recipe-korean-wings", "recipe-hot-honey-chicken"])
    ]
    static let shared: [CollectionItem] = [
        .init(name: "Circle Favorites", count: 14, shared: true, imageName: "recipe_hot_honey_chicken", recipeIds: ["recipe-hot-honey-chicken", "recipe-butter-chicken", "recipe-tuscan-salmon"]),
        .init(name: "Roommate Dinners", count: 6, shared: true, imageName: "recipe_paneer_wrap", recipeIds: ["recipe-spicy-paneer-wrap", "recipe-tomato-rigatoni"]),
        .init(name: "Cheat Day Cravings", count: 9, shared: true, imageName: "recipe_butter_chicken", recipeIds: ["recipe-butter-chicken", "recipe-korean-wings", "recipe-hot-honey-chicken"])
    ]
    static let ownedSamples: [CollectionItem] = owned
    static let sharedSamples: [CollectionItem] = shared

    /// Recipes that were added to this collection. An empty collection is empty.
    func matching(in recipes: [Recipe]) -> [Recipe] {
        guard !recipeIds.isEmpty else { return [] }
        return recipes.filter { recipeIds.contains($0.id) }
    }
}

/// Blocks harassment in comments. Whole words only, so "mustard" and "mouth" still pass.
enum CommentModeration {
    private static let words: Set<String> = [
        "fuck", "fucking", "fucker", "fucked", "shit", "bitch", "bastard", "asshole",
        "dick", "cock", "pussy", "cunt", "slut", "whore", "nigger", "nigga", "faggot",
        "retard", "rape", "rapist",
        "madarchod", "behenchod", "bhosdike", "bhosdi", "chutiya", "chutiye", "gandu",
        "randi", "harami", "muth", "muthmar", "mardu", "lund", "lauda", "jhatu", "gaand"
    ]
    private static let phrases = ["kill yourself", "kys", "muth mar"]

    static func isBlocked(_ text: String) -> Bool {
        let folded = text.lowercased()
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "$", with: "s")
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
        let tokens = folded.split { !$0.isLetter }.map { String($0) }
        if tokens.contains(where: { words.contains($0) }) { return true }
        let sentence = tokens.joined(separator: " ")
        return phrases.contains { sentence.contains($0) }
    }
}

struct SearchDemandAlert: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: String
    var queryKey: String
    var title: String
    var message: String
    var askCount: Int
    var createdAt: Date
}

struct CircleNotificationItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var message: String
    var timeAgo: String
    var symbol: String
    var isRead: Bool = false
    var recipeId: String? = nil
    /// Real event time so the screen can group rows into Today / Yesterday / Last 7 days.
    /// Optional so saves written before this field exists still decode cleanly.
    var createdAt: Date? = nil
    /// Comma-separated recipe ids merged into this notification row. Used by the 30-minute
    /// like-bundling logic in AppEnvironment — a single "You liked X and 2 others" row stays
    /// one row even as more likes fire. Optional for back-compat with older saves.
    var bundledRecipeIdsCSV: String? = nil

    /// Convenience: the recipes rolled up into this bundle. Empty for everything except batched likes.
    var bundledRecipeIds: Set<String> {
        guard let csv = bundledRecipeIdsCSV, !csv.isEmpty else {
            if let r = recipeId, !r.isEmpty { return [r] }
            return []
        }
        return Set(csv.split(separator: ",").map(String.init))
    }

    static let samples: [CircleNotificationItem] = [
        .init(title: "New Recipe in Circle", message: "@nada_dl shared 'Hot Honey Crispy Chicken Burger'", timeAgo: "10m ago", symbol: "fork.knife.circle.fill", isRead: false, recipeId: "recipe-hot-honey-chicken"),
        .init(title: "Friend Request Accepted", message: "@priyacooks accepted your Circle request", timeAgo: "1h ago", symbol: "person.crop.circle.badge.checkmark", isRead: false),
        .init(title: "Recipe Saved", message: "@Aditya.Gupta saved your 'Spicy Paneer Tikka Wrap'", timeAgo: "3h ago", symbol: "bookmark.fill", isRead: true, recipeId: "recipe-spicy-paneer-wrap"),
        .init(title: "New Shared Collection", message: "@deveats invited you to 'Roommate Dinners'", timeAgo: "1d ago", symbol: "folder.badge.plus", isRead: true)
    ]

    /// Demo rows that used to ship as a new account's activity. A real alert never uses these messages.
    static func withoutSamples(_ items: [CircleNotificationItem]) -> [CircleNotificationItem] {
        let demo = Set(samples.map(\.message))
        return items.filter { !demo.contains($0.message) }
    }
}

// MARK: - Recipe Comments Model

struct RecipeComment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var recipeId: String
    var authorName: String
    var authorUsername: String
    var text: String
    var timeAgo: String
    var likesCount: Int = 0
    var isLiked: Bool = false
    var imageData: Data? = nil      // optional photo: "here's how mine turned out"
    var createdAt: Date? = nil
    /// What the row shows. A synced comment uses the real time; older local rows keep their label.
    var displayTime: String {
        guard let createdAt else { return timeAgo }
        let age = Date().timeIntervalSince(createdAt)
        if age < 45 { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    var initials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        let clean = authorUsername.replacingOccurrences(of: "@", with: "")
        return String(clean.prefix(2)).uppercased()
    }

    var sampleKey: String { "\(authorUsername)|\(text)" }

    /// Server list wins. A comment still waiting to upload stays. The demo rows do not.
    /// ponytail: likes and photos stay on the phone that made them; the shared row is the text.
    static func synced(remote: [RecipeComment], local: [RecipeComment]) -> [RecipeComment] {
        let demo = Set(defaultSamples.values.flatMap { $0.map(\.sampleKey) })
        let remoteIds = Set(remote.map(\.id))
        let localById = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let pending = local.filter { !remoteIds.contains($0.id) && !demo.contains($0.sampleKey) }
        let filled = remote.map { row -> RecipeComment in
            var copy = row
            if let old = localById[row.id] {
                copy.imageData = old.imageData
                copy.isLiked = old.isLiked
                copy.likesCount = old.likesCount
            }
            return copy
        }
        return (pending + filled).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    static let defaultSamples: [String: [RecipeComment]] = [
        "recipe-hot-honey-chicken": [
            .init(recipeId: "recipe-hot-honey-chicken", authorName: "Dev Sharma", authorUsername: "@deveats", text: "Made this for dinner yesterday, the crunch was unbelievable! Used Frank's RedHot for the honey glaze 🔥", timeAgo: "2h ago", likesCount: 5, isLiked: true),
            .init(recipeId: "recipe-hot-honey-chicken", authorName: "Priya Menon", authorUsername: "@priyacooks", text: "Such a great weeknight dinner! The slaw cuts through the richness perfectly.", timeAgo: "5h ago", likesCount: 2, isLiked: false)
        ],
        "recipe-spicy-paneer-wrap": [
            .init(recipeId: "recipe-spicy-paneer-wrap", authorName: "Aditya Gupta", authorUsername: "@Aditya.Gupta", text: "The marinade ratio is perfection. I added pickled red onions on top!", timeAgo: "1d ago", likesCount: 8, isLiked: true),
            .init(recipeId: "recipe-spicy-paneer-wrap", authorName: "Zaatar & Zeal", authorUsername: "@zaatarandzeal", text: "Air fried the paneer cubes at 200°C for 6 mins and they came out so soft and smoky.", timeAgo: "2d ago", likesCount: 4, isLiked: false)
        ],
        "recipe-tuscan-salmon": [
            .init(recipeId: "recipe-tuscan-salmon", authorName: "Nada Al-Hassan", authorUsername: "@nada_dl", text: "Restaurant quality at home! The sun-dried tomato cream sauce is liquid gold.", timeAgo: "3h ago", likesCount: 6, isLiked: true)
        ],
        "recipe-tomato-rigatoni": [
            .init(recipeId: "recipe-tomato-rigatoni", authorName: "Kristy Graver", authorUsername: "@Kristy.Graver", text: "Tearing the fresh burrata over hot pasta is pure therapy. 10/10 comfort meal!", timeAgo: "4h ago", likesCount: 11, isLiked: true)
        ]
    ]
}

#if DEBUG
// MARK: - Meal Plan

enum MealSlot: String, Codable, CaseIterable, Hashable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }

    /// Default slot picked from a cook time — "when it is" nudges the user to the right slot
    /// without them having to tap anything. User can override, of course.
    static func suggested(for date: Date, in calendar: Calendar = .current) -> MealSlot {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 0..<10:   return .breakfast
        case 10..<15:  return .lunch
        case 17..<22:  return .dinner
        default:       return .snack
        }
    }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch:     return "sun.max"
        case .dinner:    return "moon.stars"
        case .snack:     return "cup.and.saucer"
        }
    }
}

/// One scheduled cook. Each row = "I want to make recipe X on this date, in this slot."
/// Lives locally in a per-user JSON file + mirrors to `cravecircle.meal_plan` on Supabase.
struct PlannedMeal: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var recipeId: String
    var when: Date
    var slot: MealSlot
    /// UNNotificationRequest identifier we scheduled for this cook. Kept so cancelling the
    /// plan can cancel the local notification too.
    var reminderIdentifier: String?
    var createdAt: Date = Date()
}

enum CraveCircleInvariantChecks {
    static let _runChecks: Void = {
        precondition(Recipe.isSocialImportURL(nil) == false)
        precondition(Recipe.isSocialImportURL("https://www.instagram.com/reel/AbC123/") == true)
        precondition(Recipe.isSocialImportURL("https://tiktok.com/@x/video/1") == true)
        precondition(Recipe.isSocialImportURL("https://cravecircle.cc/recipes/1") == false)
        precondition(AccountRole.user.canPublish == false)
        precondition(AccountRole.creator.canPublish == true)
        precondition(AccountRole.admin.canPublish == true)
    }()
}
#endif
