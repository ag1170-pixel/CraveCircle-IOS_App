//
//  RecommendationEngine.swift
//  CraveCircle (AICookBook)
//
//  On-device, content-based recommender. It reads the user's own interaction history
//  (views weighted by dwell time, plus likes / saves / grocery-adds / cooks) and ranks
//  candidate recipes by how similar they are to what the user actually engages with —
//  so "Suggested for You" reflects what they spend time on, not a random shuffle.
//
//  This runs entirely on-device (private, zero-latency, no server needed). When the Supabase
//  scoring RPC lands it can replace or blend with this; the interface stays the same.
//

import Foundation

enum RecommendationEngine {

    /// How strongly each kind of interaction signals real interest. Dwell (a `view`) is scored
    /// separately from its duration; explicit intent (cooking, shopping) outweighs a glance.
    private static func baseWeight(for eventType: String) -> Double {
        switch eventType {
        case "cook":    return 6      // started cooking — strongest signal
        case "grocery": return 5      // added ingredients to shop — high intent
        case "save":    return 4
        case "like":    return 4
        case "comment": return 2
        case "view":    return 1      // a glance; dwell time adds the rest (see below)
        default:        return 1
        }
    }

    /// Ranked suggestions. `history` is the user's own events; `excluding` are recipes to keep
    /// out of the feed (owned, already saved). Falls back to a fresh, un-owned sample when there
    /// isn't enough signal yet (cold start), so a brand-new user still sees something sensible.
    static func suggestions(
        from allRecipes: [Recipe],
        history: [AppEnvironment.InteractionEvent],
        excluding excludedIds: Set<String>,
        preferredCuisines: Set<String> = [],
        limit: Int = 8
    ) -> [Recipe] {
        let candidates = allRecipes.filter { !excludedIds.contains($0.id) }
        guard !candidates.isEmpty else { return [] }

        let byId = Dictionary(allRecipes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // Build the taste profile: a weighted bag of tokens from every recipe the user engaged with.
        var profile: [String: Double] = [:]
        var totalSignal = 0.0
        for event in history {
            guard let recipe = byId[event.recipeId] else { continue }
            var weight = baseWeight(for: event.eventType)
            if event.eventType == "view", let secs = event.durationSeconds {
                // Longer dwell = stronger interest, capped so one long view can't dominate.
                weight += min(Double(secs) / 10.0, 4.0)
            }
            guard weight > 0 else { continue }
            totalSignal += weight
            for token in tokens(for: recipe) {
                profile[token, default: 0] += weight
            }
        }

        // Cold start / too little signal → rank by the cuisines picked at onboarding (so the feed
        // is personal on day one), else a fresh sample.
        guard totalSignal >= 2, !profile.isEmpty else {
            if !preferredCuisines.isEmpty {
                let ranked = candidates.map { ($0, cuisineMatchCount($0, preferredCuisines)) }
                    .sorted { $0.1 > $1.1 }
                if ranked.first?.1 ?? 0 > 0 { return Array(ranked.prefix(limit).map { $0.0 }) }
            }
            return Array(candidates.shuffled().prefix(limit))
        }

        // Score each candidate by cosine-style similarity to the profile, normalized by the
        // candidate's own token count so long ingredient lists don't win automatically.
        let scored = candidates.map { recipe -> (Recipe, Double) in
            let toks = tokens(for: recipe)
            guard !toks.isEmpty else { return (recipe, 0) }
            let dot = toks.reduce(0.0) { $0 + (profile[$1] ?? 0) }
            return (recipe, dot / Double(toks.count).squareRoot())
        }

        let ranked = scored.sorted { $0.1 > $1.1 }
        // If nothing matched the profile at all (i.e. zero interaction and no preferences),
        // return empty instead of a random sample, hiding the section until they build history.
        if ranked.first?.1 ?? 0 <= 0 {
            return []
        }
        return ranked.prefix(limit).map { $0.0 }
    }

    /// A short, honest reason a recipe is suggested — the engaged recipe that most drove the match
    /// (e.g. "Because you cooked Paneer Tikka"). Returns nil when there isn't a real personalized
    /// signal yet, so the UI simply shows no chip rather than inventing one.
    static func reason(for candidate: Recipe, history: [AppEnvironment.InteractionEvent], allRecipes: [Recipe]) -> String? {
        let byId = Dictionary(allRecipes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let candTokens = tokens(for: candidate)
        guard !candTokens.isEmpty else { return nil }

        // Strongest single interaction per source recipe (a cook outweighs a glance).
        var strongest: [String: (weight: Double, event: String)] = [:]
        for e in history {
            guard let r = byId[e.recipeId], r.id != candidate.id else { continue }
            var w = baseWeight(for: e.eventType)
            if e.eventType == "view", let s = e.durationSeconds { w += min(Double(s) / 10.0, 4.0) }
            if let ex = strongest[r.id], ex.weight >= w { continue }
            strongest[r.id] = (w, e.eventType)
        }

        // Pick the source recipe whose token overlap × signal is largest.
        var best: (title: String, event: String, score: Double)?
        for (rid, info) in strongest {
            guard let r = byId[rid] else { continue }
            let overlap = tokens(for: r).intersection(candTokens).count
            guard overlap > 0 else { continue }
            let score = info.weight * Double(overlap)
            if best == nil || score > best!.score { best = (r.title, info.event, score) }
        }
        guard let best else { return nil }
        return "Because you \(verb(best.event)) \(best.title)"
    }

    private static func verb(_ eventType: String) -> String {
        switch eventType {
        case "cook":    return "cooked"
        case "grocery": return "shopped for"
        case "save":    return "saved"
        case "like":    return "liked"
        case "comment": return "commented on"
        default:        return "viewed"
        }
    }

    // MARK: - Cuisines (onboarding taste picks → day-one personalization)

    /// The cuisines offered at onboarding, each with signature keywords found in a recipe's title
    /// or ingredients. Keys are stable ids stored in `preferredCuisines`.
    static let cuisines: [(id: String, label: String, keywords: [String])] = [
        ("indian",        "Indian",        ["paneer","masala","curry","tikka","dal","daal","naan","tandoori","ghee","garam","biryani","chutney","samosa"]),
        ("italian",       "Italian",       ["pasta","rigatoni","spaghetti","parmesan","basil","mozzarella","risotto","pesto","pizza","carbonara","lasagna"]),
        ("mexican",       "Mexican",       ["taco","burrito","salsa","chipotle","guacamole","tortilla","quesadilla","enchilada","jalapeno"]),
        ("korean",        "Korean",        ["gochujang","kimchi","bibimbap","bulgogi","tteokbokki","gochugaru"]),
        ("thai",          "Thai",          ["thai","lemongrass","coconut milk","pad","tom yum","fish sauce","basil"]),
        ("chinese",       "Chinese",       ["soy","hoisin","szechuan","sichuan","dumpling","fried rice","noodle","wok","ginger scallion"]),
        ("japanese",      "Japanese",      ["miso","soy","teriyaki","udon","ramen","sushi","dashi","panko","gyoza"]),
        ("mediterranean", "Mediterranean", ["hummus","feta","olive","falafel","tahini","pita","tzatziki","shakshuka","harissa"]),
        ("american",      "American",      ["burger","bbq","cheddar","bacon","fries","mac and cheese","buffalo","pancake"]),
        ("desserts",      "Desserts",      ["sugar","chocolate","vanilla","cake","cookie","caramel","cream","pancake","tiramisu"])
    ]

    private static func recipeText(_ r: Recipe) -> String {
        (r.title + " " + r.ingredients.flatMap { $0.items }.joined(separator: " ")).lowercased()
    }

    private static func cuisineMatchCount(_ r: Recipe, _ ids: Set<String>) -> Int {
        let text = recipeText(r)
        return cuisines
            .filter { ids.contains($0.id) }
            .reduce(0) { $0 + ($1.keywords.contains { text.contains($0) } ? 1 : 0) }
    }

    /// A cold-start reason ("Because you love Indian") when a suggestion matches a picked cuisine.
    static func cuisineReason(for r: Recipe, preferredCuisines ids: Set<String>) -> String? {
        let text = recipeText(r)
        for c in cuisines where ids.contains(c.id) {
            if c.keywords.contains(where: { text.contains($0) }) { return "Because you love \(c.label)" }
        }
        return nil
    }

    // MARK: - Feature extraction

    /// Tokens that describe a recipe: words from its title and ingredient names, plus the creator
    /// handle as a strong single token (following a creator's taste is a real signal).
    private static func tokens(for recipe: Recipe) -> Set<String> {
        var out = Set<String>()
        out.formUnion(words(recipe.title))
        for group in recipe.ingredients {
            for item in group.items { out.formUnion(words(item)) }
        }
        if let handle = recipe.ownerUsername, !handle.isEmpty {
            out.insert("@" + handle.replacingOccurrences(of: "@", with: "").lowercased())
        }
        return out
    }

    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "you", "your", "this", "that", "from", "into", "add", "cup",
        "cups", "tbsp", "tsp", "tablespoon", "teaspoon", "gram", "grams", "ounce", "ounces", "pinch",
        "fresh", "chopped", "sliced", "diced", "large", "small", "medium", "cut", "some", "taste",
        "min", "mins", "minute", "minutes", "recipe", "easy", "quick", "best", "make", "made"
    ]

    private static func words(_ text: String) -> Set<String> {
        let cleaned = text.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return Set(
            String(cleaned)
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 && !stopwords.contains($0) && Int($0) == nil }
        )
    }
}
