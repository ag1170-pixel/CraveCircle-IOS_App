import Foundation

/// App account role. Consumers browse; creators (Studio-enrolled) publish; admin is the founder.
enum AccountRole: String, Codable {
    case user
    case creator
    case admin

    var canPublish: Bool { self == .creator || self == .admin }

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

    var canPublish: Bool { role.canPublish }

    init(id: String, username: String? = nil, fullName: String? = nil, avatarUrl: String? = nil, role: AccountRole = .user) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        role = try c.decodeIfPresent(AccountRole.self, forKey: .role) ?? .user
    }
}

enum ImportStatus: String, Codable {
    case queued
    case downloading
    case transcribing
    case extracting
    case done
    case error

    var displayLabel: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading reel"
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

    /// One unified time for the header: prep + cook summed into a single figure. Values are free-form
    /// ("15 min", "1 hr 10 min"), so we pull hours/minutes from each and re-format. Falls back to
    /// whichever single value exists (unparsed) when neither carries a number.
    var totalTimeText: String? {
        let mins = [prepTime, cookTime].compactMap { Recipe.minutes(from: $0) }
        guard !mins.isEmpty else { return prepTime ?? cookTime }
        return Recipe.formatMinutes(mins.reduce(0, +))
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
}

struct CircleNotificationItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var message: String
    var timeAgo: String
    var symbol: String
    var isRead: Bool = false
    var recipeId: String? = nil

    static let samples: [CircleNotificationItem] = [
        .init(title: "New Recipe in Circle", message: "@nada_dl shared 'Hot Honey Crispy Chicken Burger'", timeAgo: "10m ago", symbol: "fork.knife.circle.fill", isRead: false, recipeId: "recipe-hot-honey-chicken"),
        .init(title: "Friend Request Accepted", message: "@priyacooks accepted your Circle request", timeAgo: "1h ago", symbol: "person.crop.circle.badge.checkmark", isRead: false),
        .init(title: "Recipe Saved", message: "@Aditya.Gupta saved your 'Spicy Paneer Tikka Wrap'", timeAgo: "3h ago", symbol: "bookmark.fill", isRead: true, recipeId: "recipe-spicy-paneer-wrap"),
        .init(title: "New Shared Collection", message: "@deveats invited you to 'Roommate Dinners'", timeAgo: "1d ago", symbol: "folder.badge.plus", isRead: true)
    ]
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
    var initials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        let clean = authorUsername.replacingOccurrences(of: "@", with: "")
        return String(clean.prefix(2)).uppercased()
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
