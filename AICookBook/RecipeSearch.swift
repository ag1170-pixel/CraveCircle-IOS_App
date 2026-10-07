//
//  RecipeSearch.swift
//  CraveCircle (AICookBook)
//
//  Ingredient-aware search + filtering. Query matches title, creator, description AND ingredient
//  names ("what can I make with paneer?"). Filters are inferred on-device from the recipe's own
//  ingredients / times / nutrition — no extra data needed. Pure functions, easy to unit-test.
//

import Foundation

enum DietFilter: String, CaseIterable { case any, veg, nonVeg, vegan }
enum TimeFilter: String, CaseIterable { case any, under15, mid, long }

struct RecipeFilters: Equatable {
    var diet: DietFilter = .any
    var time: TimeFilter = .any
    var highProtein = false
    var isActive: Bool { diet != .any || time != .any || highProtein }
}

enum RecipeSearch {

    /// Ranked search result. `isGuess` is true when nothing matched the query and these are the
    /// closest-dish best guesses instead — so the UI can label them "you might like" and NEVER show
    /// an empty screen.
    struct Result {
        let recipes: [Recipe]
        let isGuess: Bool
    }

    /// Smart, typo-tolerant, keyword-aware search. Applies filters, then ranks by relevance
    /// (title > ingredients > creator/description, with prefix + fuzzy + synonym matching). When
    /// no recipe matches, returns the nearest dishes as guesses rather than an empty list.
    static func search(_ recipes: [Recipe], query: String, filters: RecipeFilters) -> Result {
        let base = recipes.filter {
            dietOK($0, filters.diet) && timeOK($0, filters.time) && (!filters.highProtein || isHighProtein($0))
        }
        let raw = normalize(query)
        guard !raw.isEmpty else { return Result(recipes: base, isGuess: false) }

        let terms = expand(tokenize(raw))
        let scored = base.map { ($0, score($0, terms: terms, raw: raw)) }
        let hits = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        if !hits.isEmpty { return Result(recipes: hits.map(\.0), isGuess: false) }

        // Never empty: rank the whole (filtered) set by fuzzy closeness and offer the nearest dishes.
        let guesses = base
            .map { ($0, closeness($0, terms: terms)) }
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map(\.0)
        return Result(recipes: Array(guesses), isGuess: !guesses.isEmpty)
    }

    /// Back-compat filter-only / substring search (used by tests). Prefer `search` in the UI.
    static func apply(_ recipes: [Recipe], query: String, filters: RecipeFilters) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return recipes.filter { r in
            (q.isEmpty || matches(r, q)) &&
            dietOK(r, filters.diet) &&
            timeOK(r, filters.time) &&
            (!filters.highProtein || isHighProtein(r))
        }
    }

    // MARK: - Scoring (ranked, typo-tolerant, keyword-aware)

    private static let stopWords: Set<String> = ["recipe","recipes","with","for","a","an","the","i",
        "want","to","eat","eating","make","making","some","something","dish","dishes","food","how",
        "me","my","please","can","cook","cooking","of","and","in","on","that","this"]

    /// Query-term synonyms so "aubergine" finds eggplant, "prawns" finds shrimp, "aloo" finds potato.
    private static let synonyms: [String: [String]] = [
        "aubergine": ["eggplant", "brinjal"], "brinjal": ["eggplant"], "eggplant": ["brinjal"],
        "capsicum": ["pepper", "bell"], "coriander": ["cilantro"], "cilantro": ["coriander"],
        "curd": ["yogurt", "yoghurt", "dahi"], "dahi": ["curd", "yogurt"],
        "prawn": ["shrimp"], "prawns": ["shrimp"], "shrimp": ["prawn"],
        "aloo": ["potato"], "gobi": ["cauliflower"], "chawal": ["rice"], "chana": ["chickpea"],
        "roti": ["bread", "chapati"], "chapati": ["roti", "bread"], "maggi": ["noodles"],
        "noodle": ["noodles", "pasta"], "cuppa": ["tea"], "sweet": ["dessert", "mithai"],
        "nonveg": ["chicken", "mutton", "fish"], "veggie": ["vegetable", "veg"]
    ]

    private static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokenize(_ q: String) -> [String] {
        q.split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 && !stopWords.contains($0) }
    }

    /// Add synonyms + a naive singular so "tomatoes"/"eggs" still match "tomato"/"egg".
    private static func expand(_ tokens: [String]) -> [String] {
        var out = Set(tokens)
        for t in tokens {
            synonyms[t].map { out.formUnion($0) }
            if t.count > 3, t.hasSuffix("s") { out.insert(String(t.dropLast())) }
        }
        return Array(out)
    }

    private static func score(_ r: Recipe, terms: [String], raw: String) -> Int {
        let title = r.title.lowercased()
        let titleWords = title.split(separator: " ").map(String.init)
        let ing = ingredientText(r)
        let creator = r.ownerUsername?.lowercased() ?? ""
        let desc = r.description?.lowercased() ?? ""

        var s = 0
        if title.contains(raw) { s += 100 }                 // whole-query title hit = strongest
        for t in terms {
            if title.contains(t) { s += 30 }
            else if titleWords.contains(where: { $0.hasPrefix(t) || t.hasPrefix($0) }) { s += 22 }
            else if titleWords.contains(where: { fuzzyEqual($0, t) }) { s += 18 }   // typo tolerance
            if ing.contains(t) { s += 12 }
            if creator.contains(t) { s += 8 }
            if desc.contains(t) { s += 5 }
        }
        return s
    }

    /// Fuzzy closeness for the never-empty fallback: higher = title is nearer to the query terms.
    private static func closeness(_ r: Recipe, terms: [String]) -> Int {
        let titleWords = r.title.lowercased().split(separator: " ").map(String.init)
        guard !titleWords.isEmpty, !terms.isEmpty else { return 0 }
        return terms.reduce(0) { acc, t in
            let best = titleWords.map { 100 - min(levenshtein($0, t), 100) }.max() ?? 0
            return acc + best
        }
    }

    /// Words count as the "same" when within one edit (handles single typos on words ≥4 chars).
    private static func fuzzyEqual(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard max(a.count, b.count) >= 4, abs(a.count - b.count) <= 1 else { return false }
        return levenshtein(a, b) <= 1
    }

    /// Classic Levenshtein edit distance (small strings — fine for a food query).
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }

    // MARK: - Query match (title / creator / description / ingredients)

    private static func matches(_ r: Recipe, _ q: String) -> Bool {
        if r.title.lowercased().contains(q) { return true }
        if r.ownerUsername?.lowercased().contains(q) == true { return true }
        if r.description?.lowercased().contains(q) == true { return true }
        return r.ingredients.contains { $0.items.contains { $0.lowercased().contains(q) } }
    }

    // MARK: - Diet (inferred from ingredients; egg counts as non-veg, Indian convention)

    private static let meatFish = ["chicken","beef","pork","mutton","lamb","bacon","ham","turkey",
        "fish","salmon","tuna","prawn","shrimp","crab","meat","sausage","pepperoni","anchovy"]
    private static let eggWords = ["egg"]
    private static let dairyWords = ["milk","butter","cheese","cream","paneer","ghee","yogurt",
        "yoghurt","curd","khoya","mozzarella","parmesan","ricotta","mascarpone"]

    private static func ingredientText(_ r: Recipe) -> String {
        r.ingredients.flatMap { $0.items }.joined(separator: " ").lowercased()
    }

    static func dietClass(_ r: Recipe) -> DietFilter {
        let text = ingredientText(r)
        let hasMeatFish = meatFish.contains { text.contains($0) }
        let hasEgg = eggWords.contains { text.contains($0) }
        let hasDairy = dairyWords.contains { text.contains($0) }
        if hasMeatFish || hasEgg { return .nonVeg }
        return hasDairy ? .veg : .vegan   // vegan is a stricter veg
    }

    private static func dietOK(_ r: Recipe, _ f: DietFilter) -> Bool {
        switch f {
        case .any:    return true
        case .nonVeg: return dietClass(r) == .nonVeg
        case .veg:    return dietClass(r) != .nonVeg          // veg OR vegan
        case .vegan:  return dietClass(r) == .vegan
        }
    }

    // MARK: - Time (parsed from prep + cook)

    static func totalMinutes(_ r: Recipe) -> Int {
        parseMinutes(r.prepTime) + parseMinutes(r.cookTime)
    }

    private static func parseMinutes(_ s: String?) -> Int {
        guard let s = s?.lowercased() else { return 0 }
        let nums = s.split { !$0.isNumber }.compactMap { Int($0) }
        guard let first = nums.first else { return 0 }
        if s.contains("hr") || s.contains("hour") || s.contains(" h") {
            return first * 60 + (nums.dropFirst().first ?? 0)   // "1 hr 20 min"
        }
        return first
    }

    private static func timeOK(_ r: Recipe, _ f: TimeFilter) -> Bool {
        let t = totalMinutes(r)
        switch f {
        case .any:     return true
        case .under15: return t > 0 && t <= 15
        case .mid:     return t > 15 && t <= 30
        case .long:    return t > 30
        }
    }

    // MARK: - High protein (nutrition when known, else ingredient signal)

    private static let proteinWords = ["chicken","paneer","tofu","egg","lentil","dal","daal","beans",
        "chickpea","fish","shrimp","prawn","greek yogurt","protein","tempeh","edamame","turkey","beef"]

    static func isHighProtein(_ r: Recipe) -> Bool {
        if let p = r.nutrition?.proteinG { return p >= 20 }
        let text = ingredientText(r)
        return proteinWords.contains { text.contains($0) }
    }
}
