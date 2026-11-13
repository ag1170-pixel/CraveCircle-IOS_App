//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: GrocerySort.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Supermarket aisle categorization and deduplication algorithm for grocery items.
//
// 2. ARCHITECTURAL ROLE:
//    Analyzes ingredient names to assign aisle categories and combines fractional amounts across recipes.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "GrocerySort contains the algorithmic intelligence of our shopping list. It parses raw ingredient names, maps them to realistic supermarket aisles, and sums quantities so you buy one item instead of three duplicate entries."
//
// ==============================================================================
//

//
//  GrocerySort.swift
//  CraveCircle (AICookBook)
//
//  Groups a grocery list by supermarket aisle and de-duplicates ingredients, so a list built from
//  several recipes reads like something you'd actually shop from (all produce together, one "olive
//  oil" not three). Keyword-based, on-device — no data beyond the ingredient text.
//

import Foundation

enum GroceryAisle: String, CaseIterable {
    case produce, meatFish, dairy, bakery, frozen, pantry, spices, beverages, other

    var label: String {
        switch self {
        case .produce:   return "Produce"
        case .meatFish:  return "Meat & Fish"
        case .dairy:     return "Dairy & Eggs"
        case .bakery:    return "Bakery"
        case .frozen:    return "Frozen"
        case .pantry:    return "Pantry"
        case .spices:    return "Spices & Herbs"
        case .beverages: return "Beverages"
        case .other:     return "Other"
        }
    }

    var icon: String {
        switch self {
        case .produce:   return "carrot"
        case .meatFish:  return "fish"
        case .dairy:     return "drop"
        case .bakery:    return "birthday.cake"
        case .frozen:    return "snowflake"
        case .pantry:    return "cabinet"
        case .spices:    return "leaf"
        case .beverages: return "cup.and.saucer"
        case .other:     return "bag"
        }
    }
}

/// How the grocery list is grouped — matches Osta's "By Recipe / By Aisle" sort options.
enum GrocerySortMode: String, CaseIterable {
    case recipe, aisle
    var label: String { self == .recipe ? "By Recipe" : "By Aisle" }
}

enum GrocerySort {

    /// Aisle for an ingredient line, matched most-specific first (meat/fish before produce so
    /// "chicken stock" lands in the right place). Falls back to Other.
    static func aisle(for name: String) -> GroceryAisle {
        let t = name.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if has(["chicken","beef","pork","mutton","lamb","bacon","sausage","turkey","fish","salmon","tuna","prawn","shrimp","crab","meat"]) { return .meatFish }
        if has(["bread","bun","tortilla","naan","pita","baguette","roll","croissant","bagel"]) { return .bakery }
        if has(["frozen","ice cream","ice-cream"]) { return .frozen }
        if has(["milk","butter","cheese","cream","paneer","yogurt","yoghurt","curd","ghee","egg","mozzarella","parmesan","ricotta"]) { return .dairy }
        if has(["water","juice","soda","wine","beer","tea","coffee","cola","lemonade"]) { return .beverages }
        // Spice/masala FORMS before produce, so "garlic powder", "chili powder" and "garam masala"
        // land in Spices rather than Produce (which matches the raw "garlic"/"chili" word).
        if has(["masala","garam"]) { return .spices }
        if t.contains("powder"), !t.contains("baking"), !t.contains("custard") { return .spices }
        if has(["cumin","turmeric","paprika","cinnamon","oregano","cardamom","clove","nutmeg","bay leaf","seasoning","spice","seeds"]) { return .spices }
        if t.contains("paste"), !t.contains("tomato") { return .pantry }   // ginger-garlic paste etc.
        if has(["onion","garlic","tomato","potato","spinach","lettuce","chilli","chili","ginger","lemon","lime","carrot","cucumber","cilantro","coriander","basil","mint","parsley","avocado","mushroom","broccoli","cauliflower","corn","peas","apple","banana","berry","scallion","spring onion","kale","zucchini","eggplant","capsicum","bell pepper"]) { return .produce }
        if has(["flour","rice","pasta","noodle","oil","sugar","salt","sauce","vinegar","lentil","dal","daal","beans","chickpea","stock","broth","oats","honey","ketchup","mayo","canned","paste","coconut milk","soy","syrup","baking"]) { return .pantry }
        return .other
    }

    static let handAddedLabel = "Added by you"

    static func dishName(_ item: GroceryItem) -> String {
        item.recipeName ?? handAddedLabel
    }

    /// Finishing All clears the list. Finishing one dish drops only that dish.
    static func removingFinished(_ items: [GroceryItem], dish: String?) -> [GroceryItem] {
        guard let dish else { return [] }
        return items.filter { dishName($0) != dish }
    }

    /// Grouped by DISH (the recipe each item came from), in first-appearance order; hand-added items
    /// (no recipe) come last under "Added by you". This is how the Grocery screen reads now — you can
    /// see and shop one dish at a time. Items keep their order within a dish.
    static func groupedByDish(_ items: [GroceryItem]) -> [(dish: String, items: [GroceryItem])] {
        var order: [String] = []
        var buckets: [String: [GroceryItem]] = [:]
        for item in items {
            let key = item.recipeName ?? handAddedLabel
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        // keep "Added by you" at the end
        order.sort { a, b in (a == handAddedLabel ? 1 : 0) < (b == handAddedLabel ? 1 : 0) }
        return order.compactMap { key in buckets[key].map { (key, $0) } }
    }

    /// Distinct dish names in list order (for the filter chips). Excludes the hand-added bucket.
    static func dishes(_ items: [GroceryItem]) -> [String] {
        var seen = Set<String>(); var out: [String] = []
        for item in items { if let r = item.recipeName, !seen.contains(r) { seen.insert(r); out.append(r) } }
        return out
    }

    /// Grouped and ordered by aisle (produce first). Items keep their original order within an aisle.
    static func grouped(_ items: [GroceryItem]) -> [(aisle: GroceryAisle, items: [GroceryItem])] {
        var buckets: [GroceryAisle: [GroceryItem]] = [:]
        for item in items { buckets[aisle(for: item.ingredientName), default: []].append(item) }
        return GroceryAisle.allCases.compactMap { a in
            guard let items = buckets[a], !items.isEmpty else { return nil }
            return (a, items)
        }
    }

    /// One row on the aisle list: the same ingredient from several recipes collapsed together.
    struct MergedRow: Identifiable {
        let items: [GroceryItem]
        var id: String { items[0].id }
        var checked: Bool { items.allSatisfy(\.checked) }
        /// Distinct dishes this ingredient came from, in list order ("Added by you" for hand-added).
        var recipes: [String] {
            var seen = Set<String>()
            return items.map(dishName).filter { seen.insert($0).inserted }
        }
    }

    /// Collapse rows that are the same ingredient (by `coreName`) into one, keeping first-seen order.
    static func merged(_ items: [GroceryItem]) -> [MergedRow] {
        var order: [String] = []
        var buckets: [String: [GroceryItem]] = [:]
        for item in items {
            let core = mergeKey(item.ingredientName)
            let key = core.isEmpty ? item.id : core
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(item)
        }
        return order.compactMap { buckets[$0].map(MergedRow.init) }
    }

    /// Prep and grade words that don't change what you buy ("minced garlic" is still garlic).
    private static let prepWords: Set<String> = [
        "minced", "chopped", "fresh", "freshly", "extra", "virgin", "unsalted", "salted", "ground",
        "dried", "grated", "sliced", "diced", "crushed", "finely", "roughly", "thinly", "large",
        "small", "medium", "whole", "boneless", "skinless", "peeled", "cubed", "softened", "melted",
        "organic", "ripe", "raw", "toasted", "roasted", "shredded", "halved", "quartered", "julienned",
    ]

    /// Key for merging the same ingredient across recipes: `coreName` minus prep words, last
    /// word singular. "2 tbsp extra virgin olive oil" and "1 tbsp olive oil" → "olive oil".
    static func mergeKey(_ s: String) -> String {
        var words = coreName(s).split(separator: " ").map(String.init).filter { !prepWords.contains($0) }
        if var last = words.popLast() {
            if last.hasSuffix("oes") { last.removeLast(2) }
            else if last.hasSuffix("s"), !last.hasSuffix("ss"), last.count > 3 { last.removeLast() }
            words.append(last)
        }
        return words.joined(separator: " ")
    }

    /// Aisle sections built from merged rows.
    static func groupedMerged(_ items: [GroceryItem]) -> [(aisle: GroceryAisle, rows: [MergedRow])] {
        var buckets: [GroceryAisle: [MergedRow]] = [:]
        for row in merged(items) { buckets[aisle(for: row.items[0].ingredientName), default: []].append(row) }
        return GroceryAisle.allCases.compactMap { a in
            guard let rows = buckets[a], !rows.isEmpty else { return nil }
            return (a, rows)
        }
    }

    /// Combined amount for a merged row. Same unit → summed ("0.5 cup" + "0.25 cup" → "0.75 cup");
    /// anything else is listed ("2 + 1 tbsp").
    static func combinedAmount(_ amounts: [String]) -> String {
        let parts = amounts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard parts.count > 1 else { return parts.first ?? "" }
        let parsed = parts.map(parseAmount)
        if parsed.allSatisfy({ $0 != nil }) {
            let values = parsed.compactMap { $0 }
            let unit = values[0].unit
            if values.allSatisfy({ singular($0.unit) == singular(unit) }) {
                let total = values.reduce(0) { $0 + $1.value }
                let number = formatNumber(total)
                guard !unit.isEmpty else { return number }
                return "\(number) \(total > 1 ? plural(unit) : singular(unit))"
            }
        }
        var seen = Set<String>()
        return parts.filter { seen.insert($0.lowercased()).inserted }.joined(separator: " + ")
    }

    private static func parseAmount(_ s: String) -> (value: Double, unit: String)? {
        let glyphs: [Character: Double] = ["¼": 0.25, "½": 0.5, "¾": 0.75, "⅓": 1.0/3, "⅔": 2.0/3, "⅛": 0.125]
        var tokens = s.lowercased().split(separator: " ").map(String.init)
        var value = 0.0, found = false
        while let t = tokens.first {
            if let g = t.first, t.count == 1, let v = glyphs[g] { value += v }
            else if let v = Double(t) { value += v }
            else if t.contains("/"), case let f = t.split(separator: "/"), f.count == 2,
                    let n = Double(f[0]), let d = Double(f[1]), d != 0 { value += n / d }
            else if let m = t.range(of: #"^[0-9.]+"#, options: .regularExpression), let v = Double(t[m]) {
                value += v; found = true
                tokens[0] = String(t[m.upperBound...]); break
            } else { break }
            found = true
            tokens.removeFirst()
        }
        guard found else { return nil }
        return (value, tokens.joined(separator: " "))
    }

    private static func singular(_ u: String) -> String {
        switch u {
        case "cups": return "cup"
        case "tablespoons": return "tablespoon"
        case "teaspoons": return "teaspoon"
        case "cloves": return "clove"
        case "grams": return "gram"
        case "pieces": return "piece"
        case "slices": return "slice"
        default: return u
        }
    }

    private static func plural(_ u: String) -> String {
        let s = singular(u)
        return ["cup", "clove", "piece", "slice", "gram", "tablespoon", "teaspoon"].contains(s) ? s + "s" : s
    }

    private static func formatNumber(_ v: Double) -> String {
        let rounded = (v * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static let units: Set<String> = ["cup","cups","tbsp","tablespoon","tablespoons","tsp",
        "teaspoon","teaspoons","g","gram","grams","kg","ml","l","oz","ounce","ounces","lb","lbs",
        "pound","pounds","clove","cloves","pinch","can","cans","slice","slices","piece","pieces",
        "handful","bunch","stick","sticks","cup.","large","small","medium"]

    /// Split a line into its leading quantity ("1 tbsp", "500g", "3 cloves") and the ingredient name,
    /// so the row can show the name on the left and the amount on the right. Handles numbers, fractions,
    /// ranges, unit words, and number-glued-to-unit ("500g"). If nothing reads as a quantity, qty is "".
    static func splitQuantity(_ s: String) -> (qty: String, name: String) {
        let tokens = s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        func isQty(_ t: String) -> Bool {
            let w = t.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if w.range(of: #"^[0-9¼½¾⅓⅔⅛⅜⅝⅞/.\-–]+$"#, options: .regularExpression) != nil { return true } // 2, 1/2, 2-3
            if units.contains(w) { return true }                                                               // cup, tbsp…
            if w.range(of: #"^[0-9./]+[a-z]+$"#, options: .regularExpression) != nil { return true }           // 500g, 2tbsp
            return false
        }
        var i = 0
        while i < tokens.count, isQty(tokens[i]) { i += 1 }
        guard i > 0, i < tokens.count else { return ("", s) }   // all-or-nothing: never hide the name
        return (tokens[0..<i].joined(separator: " "), tokens[i...].joined(separator: " "))
    }

    /// The bare ingredient (no leading quantity/unit) — used to de-duplicate across recipes.
    /// "2 tbsp olive oil" and "1 cup olive oil" both reduce to "olive oil".
    static func coreName(_ s: String) -> String {
        var tokens = IngredientListFormat.displayParts(s).name.lowercased()
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        while let first = tokens.first, Int(first) != nil || first.contains("/") || units.contains(first) {
            tokens.removeFirst()
        }
        return tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
