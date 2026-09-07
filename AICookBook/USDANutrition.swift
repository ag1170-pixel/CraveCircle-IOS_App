//
//  USDANutrition.swift
//  CraveCircle (AICookBook)
//
//  Authoritative per-serving nutrition from USDA FoodData Central (fdc.nal.usda.gov). For each
//  ingredient we look up its reference per-100g macros and scale by the parsed grams (same gram
//  parser the on-device estimator uses), then divide by servings. Results are marked authoritative
//  (estimated = false); if the network/key is unavailable we return nil and the caller keeps the
//  on-device estimate.
//
//  Needs a free api.data.gov key (https://fdc.nal.usda.gov/api-key-signup.html). DEMO_KEY works but
//  is rate-limited to ~30 requests/hour — fine to try, not for real use. Long term this is best
//  computed once server-side at import and stored; the client path is the fallback.
//

import Foundation

enum USDANutrition {
    private struct Macro { let kcal, carbs, protein, fat: Double }

    // Per-ingredient results cached across recipes so common items ("onion", "olive oil") don't
    // re-hit the API. `nil` caches a confirmed miss so we don't retry it every time. Guarded by a
    // lock because compute() runs on concurrent background tasks (an unguarded Dictionary can crash).
    private static var cache: [String: Macro?] = [:]
    private static let cacheLock = NSLock()

    private static func cached(_ q: String) -> Macro?? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        return cache[q]
    }
    private static func store(_ q: String, _ m: Macro?) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cache[q] = m
    }

    /// Compute authoritative per-serving nutrition, or nil if too little could be resolved.
    static func compute(for recipe: Recipe, apiKey: String) async -> RecipeNutrition? {
        let servings = Double(max(recipe.servings ?? 2, 1))
        var kcal = 0.0, carbs = 0.0, protein = 0.0, fat = 0.0
        var resolved = 0, total = 0

        for group in recipe.ingredients {
            for item in group.items where !item.trimmingCharacters(in: .whitespaces).isEmpty {
                total += 1
                let (grams, _) = NutritionEstimator.parse(item)
                let query = GrocerySort.coreName(item)
                guard !query.isEmpty, let macro = await macros(for: query, apiKey: apiKey) else { continue }
                resolved += 1
                let f = grams / 100.0
                kcal += macro.kcal * f; carbs += macro.carbs * f
                protein += macro.protein * f; fat += macro.fat * f
            }
        }
        // Require a solid majority resolved, else the total would be misleadingly low.
        guard total > 0, Double(resolved) / Double(total) >= 0.6 else { return nil }
        return RecipeNutrition(
            calories: (kcal / servings).rounded(),
            carbsG: (carbs / servings).rounded(),
            proteinG: (protein / servings).rounded(),
            fatG: (fat / servings).rounded(),
            estimated: false   // authoritative
        )
    }

    private static func macros(for query: String, apiKey: String) async -> Macro? {
        if let hit = cached(query) { return hit }   // hit may be a cached miss (nil)
        let macro = await fetch(query, apiKey: apiKey)
        store(query, macro)
        return macro
    }

    private static func fetch(_ query: String, apiKey: String) async -> Macro? {
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search?api_key=\(apiKey)&query=\(q)&pageSize=1&dataType=Foundation,SR%20Legacy,Survey%20(FNDDS)")
        else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"] as? [[String: Any]], let food = foods.first,
              let nutrients = food["foodNutrients"] as? [[String: Any]]
        else { return nil }

        func value(_ number: String) -> Double? {
            for n in nutrients where (n["nutrientNumber"] as? String) == number {
                if let v = n["value"] as? Double { return v }
            }
            return nil
        }
        // 208 Energy(kcal), 205 Carbs, 203 Protein, 204 Fat — all per 100g.
        guard let kcal = value("208") else { return nil }
        return Macro(kcal: kcal, carbs: value("205") ?? 0, protein: value("203") ?? 0, fat: value("204") ?? 0)
    }
}
