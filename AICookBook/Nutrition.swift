//
//  Nutrition.swift
//  CraveCircle (AICookBook)
//
//  Per-serving nutrition for a recipe. Authoritative values come from the server
//  (go-api computes them from the known ingredients via a food database, e.g. USDA
//  FoodData Central, and stores them on the recipe). When the server hasn't computed
//  them yet, `NutritionEstimator` gives an on-device approximation from the ingredient
//  strings so the card still shows something — clearly marked "estimated".
//

import Foundation

/// The four things a user can tap on the nutrition card to see "where does this come from".
enum MacroKind: String, CaseIterable, Hashable {
    case calories, protein, carbs, fat
    var title: String {
        switch self {
        case .calories: return "Calories"
        case .protein:  return "Protein"
        case .carbs:    return "Carbs"
        case .fat:      return "Fat"
        }
    }
    var unit: String { self == .calories ? "kcal" : "g" }
}

/// One ingredient's contribution to the recipe's macros (per serving). Powers the tappable
/// breakdown so users can see which item brings the protein/carbs/fat and tweak recipes.
struct IngredientMacro: Codable, Hashable {
    var name: String
    var kcal: Double
    var carbsG: Double
    var proteinG: Double
    var fatG: Double

    func value(for kind: MacroKind) -> Double {
        switch kind {
        case .calories: return kcal
        case .protein:  return proteinG
        case .carbs:    return carbsG
        case .fat:      return fatG
        }
    }
}

struct RecipeNutrition: Codable, Hashable {
    var calories: Double          // per serving, kcal
    var carbsG: Double
    var proteinG: Double
    var fatG: Double
    var dailyCalories: Double = 2000
    var breakdown: [IngredientMacro]? = nil   // per-ingredient contributions (server or on-device)
    var estimated: Bool = false   // true when computed on-device rather than server-verified

    /// Ingredients contributing to `kind`, biggest first, each with its % share of that macro.
    /// Only non-zero contributors; empty when there's no breakdown data to show.
    func contributions(for kind: MacroKind) -> [(item: IngredientMacro, percent: Int)] {
        guard let breakdown, !breakdown.isEmpty else { return [] }
        let total = max(breakdown.reduce(0) { $0 + $1.value(for: kind) }, 0.0001)
        return breakdown
            .filter { $0.value(for: kind) > 0 }
            .sorted { $0.value(for: kind) > $1.value(for: kind) }
            .map { ($0, Int(($0.value(for: kind) / total * 100).rounded())) }
    }

    // % of the daily-value calorie budget this serving uses.
    var caloriesDVPercent: Int { pct(calories / dailyCalories) }

    // Macro split = share of THIS meal's calories from each macro (4/4/9 kcal per g).
    private var carbsKcal: Double { carbsG * 4 }
    private var proteinKcal: Double { proteinG * 4 }
    private var fatKcal: Double { fatG * 9 }
    private var macroKcal: Double { max(carbsKcal + proteinKcal + fatKcal, 1) }

    var carbsPercent: Int { pct(carbsKcal / macroKcal) }
    var proteinPercent: Int { pct(proteinKcal / macroKcal) }
    var fatPercent: Int { pct(fatKcal / macroKcal) }

    // Exercise burn equivalents (for a standard 70kg / 154lb adult based on METs):
    var runningMinutes: Int { Int((calories / 12.0).rounded()) }
    var cyclingMinutes: Int { Int((calories / 9.8).rounded()) }
    var walkingMinutes: Int { Int((calories / 5.3).rounded()) }
    var hiitMinutes: Int { Int((calories / 10.4).rounded()) }

    private func pct(_ v: Double) -> Int { Int((v * 100).rounded()) }
}

// MARK: - On-device estimator (fallback only)

enum NutritionEstimator {
    /// Rough per-serving estimate from ingredient lines. Server values always win.
    static func estimate(for recipe: Recipe) -> RecipeNutrition {
        let servings = Double(max(recipe.servings ?? 2, 1))
        var kcal = 0.0, carbs = 0.0, protein = 0.0, fat = 0.0
        var contribs: [IngredientMacro] = []

        for group in recipe.ingredients {
            for item in group.items where !item.trimmingCharacters(in: .whitespaces).isEmpty {
                let (grams, name) = parse(item)
                guard let macro = lookup(name) else { continue }
                let f = grams / 100.0
                kcal += macro.kcal * f
                carbs += macro.carbs * f
                protein += macro.protein * f
                fat += macro.fat * f
                contribs.append(IngredientMacro(
                    name: displayName(item),
                    kcal: macro.kcal * f, carbsG: macro.carbs * f,
                    proteinG: macro.protein * f, fatG: macro.fat * f))
            }
        }
        // Per-serving breakdown, biggest calorie contributor first (matches the server shape).
        let breakdown = contribs.sorted { $0.kcal > $1.kcal }.map {
            IngredientMacro(name: $0.name,
                            kcal: ($0.kcal / servings).rounded(),
                            carbsG: ($0.carbsG / servings * 10).rounded() / 10,
                            proteinG: ($0.proteinG / servings * 10).rounded() / 10,
                            fatG: ($0.fatG / servings * 10).rounded() / 10)
        }
        return RecipeNutrition(
            calories: (kcal / servings).rounded(),
            carbsG: (carbs / servings).rounded(),
            proteinG: (protein / servings).rounded(),
            fatG: (fat / servings).rounded(),
            breakdown: breakdown.isEmpty ? nil : breakdown,
            estimated: true
        )
    }

    /// Short readable name for the breakdown ("2 fresh onions, sliced" -> "Onions").
    private static func displayName(_ item: String) -> String {
        let core = GrocerySort.coreName(item)
        return (core.isEmpty ? item : core)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
            .capitalized
    }

    /// grams per one unit — matched as a WHOLE word (so "garlic" never matches "g").
    private static let unitGrams: [String: Double] = [
        "kg": 1000, "g": 1, "gram": 1, "grams": 1, "mg": 0.001,
        "l": 1000, "litre": 1000, "ml": 1,
        "lb": 454, "lbs": 454, "oz": 28,
        "cup": 200, "cups": 200, "tbsp": 15, "tablespoon": 15, "tsp": 5, "teaspoon": 5,
        "clove": 5, "cloves": 5, "slice": 20, "slices": 20,
        "can": 400, "pinch": 0.5, "egg": 50, "eggs": 50,
        "roti": 45, "rotis": 45, "chapati": 45
    ]

    /// Extract a gram amount + a lowercased ingredient name from a line like "300 ml buttermilk".
    /// Shared with USDANutrition so both sources scale by the same grams.
    static func parse(_ line: String) -> (grams: Double, name: String) {
        let lower = line.lowercased()

        // 1) leading quantity — decimal, "1/2", or a unicode fraction
        var qty = 1.0
        var hasNumber = false
        let uni: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0/3, "⅔": 2.0/3]
        if let first = lower.trimmingCharacters(in: .whitespaces).first, let v = uni[first] {
            qty = v; hasNumber = true
        } else {
            let sc = Scanner(string: lower); sc.charactersToBeSkipped = .whitespaces
            if let n = sc.scanDouble() {
                qty = n; hasNumber = true
                if sc.scanString("/") != nil, let d = sc.scanDouble(), d != 0 { qty = n / d }
            }
        }

        // 2) unit — first whole word that is a known unit
        let words = lower.split { !$0.isLetter }.map(String.init)
        let unit = words.first { unitGrams[$0] != nil }

        // 3) grams
        let grams: Double
        if let unit, let g = unitGrams[unit] { grams = qty * g }   // "300 ml", "2 cloves"
        else if hasNumber { grams = qty * 60 }                     // bare count, e.g. "2 rotis"
        else { grams = 80 }                                        // "onion slices", no quantity
        return (grams, lower)
    }

    private struct Macro { let kcal, carbs, protein, fat: Double }

    /// Compact table of common ingredients, per 100g. Server DB replaces this.
    private static func lookup(_ name: String) -> Macro? {
        // Ordered specific → generic; first substring match wins (so "buttermilk" ≠ "butter").
        let table: [(String, Macro)] = [
            ("buttermilk", Macro(kcal: 40, carbs: 4.8, protein: 3.3, fat: 0.9)),
            ("ghee", Macro(kcal: 900, carbs: 0, protein: 0, fat: 100)),
            ("butter", Macro(kcal: 717, carbs: 0.1, protein: 0.9, fat: 81)),
            ("cornstarch", Macro(kcal: 381, carbs: 91, protein: 0.3, fat: 0.1)),
            ("cornflour", Macro(kcal: 381, carbs: 91, protein: 0.3, fat: 0.1)),
            ("paneer", Macro(kcal: 265, carbs: 6, protein: 18, fat: 20)),
            // meats & seafood (mutton/lamb/goat were missing → main ingredient counted as 0)
            ("mutton", Macro(kcal: 165, carbs: 0, protein: 26, fat: 6)),
            ("goat", Macro(kcal: 143, carbs: 0, protein: 27, fat: 3)),
            ("lamb", Macro(kcal: 258, carbs: 0, protein: 25, fat: 17)),
            ("keema", Macro(kcal: 165, carbs: 0, protein: 26, fat: 6)),
            ("qeema", Macro(kcal: 165, carbs: 0, protein: 26, fat: 6)),
            ("mince", Macro(kcal: 165, carbs: 0, protein: 26, fat: 6)),
            ("chicken", Macro(kcal: 165, carbs: 0, protein: 31, fat: 3.6)),
            ("bacon", Macro(kcal: 541, carbs: 1.4, protein: 37, fat: 42)),
            ("beef", Macro(kcal: 250, carbs: 0, protein: 26, fat: 15)),
            ("pork", Macro(kcal: 242, carbs: 0, protein: 27, fat: 14)),
            ("prawn", Macro(kcal: 99, carbs: 0.2, protein: 24, fat: 0.3)),
            ("shrimp", Macro(kcal: 99, carbs: 0.2, protein: 24, fat: 0.3)),
            ("fish", Macro(kcal: 206, carbs: 0, protein: 22, fat: 12)),
            ("egg", Macro(kcal: 155, carbs: 1.1, protein: 13, fat: 11)),
            // legumes / flours / grains
            ("chickpea", Macro(kcal: 164, carbs: 27, protein: 9, fat: 2.6)),
            ("chana", Macro(kcal: 164, carbs: 27, protein: 9, fat: 2.6)),
            ("rajma", Macro(kcal: 127, carbs: 23, protein: 9, fat: 0.5)),
            ("lentil", Macro(kcal: 116, carbs: 20, protein: 9, fat: 0.4)),
            ("dal", Macro(kcal: 116, carbs: 20, protein: 9, fat: 0.4)),
            ("bean", Macro(kcal: 127, carbs: 23, protein: 9, fat: 0.5)),
            ("besan", Macro(kcal: 387, carbs: 58, protein: 22, fat: 7)),
            ("flour", Macro(kcal: 364, carbs: 76, protein: 10, fat: 1)),
            ("roti", Macro(kcal: 297, carbs: 46, protein: 11, fat: 7)),
            ("chapati", Macro(kcal: 297, carbs: 46, protein: 11, fat: 7)),
            ("bread", Macro(kcal: 265, carbs: 49, protein: 9, fat: 3.2)),
            ("pasta", Macro(kcal: 158, carbs: 31, protein: 6, fat: 0.9)),
            ("rice", Macro(kcal: 130, carbs: 28, protein: 2.7, fat: 0.3)),
            // nuts (rich gravies)
            ("cashew", Macro(kcal: 553, carbs: 30, protein: 18, fat: 44)),
            ("almond", Macro(kcal: 579, carbs: 22, protein: 21, fat: 50)),
            ("peanut", Macro(kcal: 567, carbs: 16, protein: 26, fat: 49)),
            // vegetables / aromatics
            ("onion", Macro(kcal: 40, carbs: 9, protein: 1.1, fat: 0.1)),
            ("tomato", Macro(kcal: 18, carbs: 3.9, protein: 0.9, fat: 0.2)),
            ("potato", Macro(kcal: 77, carbs: 17, protein: 2, fat: 0.1)),
            ("ginger", Macro(kcal: 80, carbs: 18, protein: 1.8, fat: 0.8)),
            ("garlic", Macro(kcal: 149, carbs: 33, protein: 6.4, fat: 0.5)),
            ("spinach", Macro(kcal: 23, carbs: 3.6, protein: 2.9, fat: 0.4)),
            ("carrot", Macro(kcal: 41, carbs: 10, protein: 0.9, fat: 0.2)),
            ("parsley", Macro(kcal: 36, carbs: 6, protein: 3, fat: 0.8)),
            ("mint", Macro(kcal: 44, carbs: 8, protein: 3.3, fat: 0.7)),
            ("lemon", Macro(kcal: 29, carbs: 9, protein: 1.1, fat: 0.3)),
            ("mayonnaise", Macro(kcal: 680, carbs: 0.6, protein: 1, fat: 75)),
            ("mayo", Macro(kcal: 680, carbs: 0.6, protein: 1, fat: 75)),
            // dairy (coconut BEFORE milk/cream so "coconut milk" isn't read as milk)
            ("coconut milk", Macro(kcal: 230, carbs: 6, protein: 2.3, fat: 24)),
            ("coconut", Macro(kcal: 354, carbs: 15, protein: 3.3, fat: 33)),
            ("cheese", Macro(kcal: 402, carbs: 1.3, protein: 25, fat: 33)),
            ("cream", Macro(kcal: 340, carbs: 2.8, protein: 2.1, fat: 36)),
            ("curd", Macro(kcal: 61, carbs: 4.7, protein: 3.5, fat: 3.3)),
            ("dahi", Macro(kcal: 61, carbs: 4.7, protein: 3.5, fat: 3.3)),
            ("yogurt", Macro(kcal: 61, carbs: 4.7, protein: 3.5, fat: 3.3)),
            ("yoghurt", Macro(kcal: 61, carbs: 4.7, protein: 3.5, fat: 3.3)),
            ("milk", Macro(kcal: 42, carbs: 5, protein: 3.4, fat: 1)),
            ("brown sugar", Macro(kcal: 380, carbs: 98, protein: 0, fat: 0)),
            ("sugar", Macro(kcal: 387, carbs: 100, protein: 0, fat: 0)),
            ("honey", Macro(kcal: 304, carbs: 82, protein: 0.3, fat: 0)),
            ("oil", Macro(kcal: 884, carbs: 0, protein: 0, fat: 100))
        ]
        for (key, macro) in table where name.contains(key) { return macro }
        return nil
    }
}

extension Recipe {
    /// Server value if present, otherwise an on-device estimate.
    var nutritionOrEstimate: RecipeNutrition {
        nutrition ?? NutritionEstimator.estimate(for: self)
    }
}
