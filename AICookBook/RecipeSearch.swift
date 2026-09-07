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

    static func apply(_ recipes: [Recipe], query: String, filters: RecipeFilters) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return recipes.filter { r in
            (q.isEmpty || matches(r, q)) &&
            dietOK(r, filters.diet) &&
            timeOK(r, filters.time) &&
            (!filters.highProtein || isHighProtein(r))
        }
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
