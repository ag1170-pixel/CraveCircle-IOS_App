//
//  RecipeExtractor.swift
//  CraveCircle (AICookBook)
//
//  Turns a cooking-video transcript (+ optional caption) into a structured Recipe, fully
//  on-device using iOS 26's Foundation Models framework (Apple's ~3B on-device LLM) with
//  guided generation. Falls back to a simple heuristic when the model isn't available
//  (e.g. a device/simulator without Apple Intelligence).
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum RecipeExtractor {

    static var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Extract a recipe on-device. Uses the LLM when available, otherwise a heuristic.
    /// `onScreenText` is Vision-OCR'd overlay text — the main source for silent, caption-less reels.
    /// `targetLanguage` — when set and different from the source, the LLM writes the recipe's
    /// user-facing text in that language, so a Tamil user importing an English reel gets a Tamil
    /// recipe in one pass. The heuristic fallback can't translate; it delivers in source language.
    static func extract(transcript: String, caption: String?, ownerId: String,
                        sourceLanguage: String?, onScreenText: String? = nil,
                        targetLanguage: AppLanguage? = nil) async -> Recipe {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            if let recipe = try? await generate(transcript: transcript, caption: caption,
                                                onScreenText: onScreenText,
                                                ownerId: ownerId, sourceLanguage: sourceLanguage,
                                                targetLanguage: targetLanguage) {
                return applyingCaptionNutrition(recipe, caption: caption, onScreenText: onScreenText)
            }
        }
        #endif
        return applyingCaptionNutrition(
            heuristic(transcript: transcript, caption: caption, onScreenText: onScreenText,
                      ownerId: ownerId, sourceLanguage: sourceLanguage),
            caption: caption, onScreenText: onScreenText)
    }

    /// True when the assembled recipe reads like actual cooking — it has cooking verbs, measurements,
    /// or common ingredients. Runs AFTER translation so English food words are present regardless of
    /// the reel's source language. Deliberately lenient: better to accept a borderline recipe than
    /// reject a real one (a fashion/product clip has none of these signals and is turned away).
    static func looksLikeFood(_ recipe: Recipe) -> Bool {
        let text = ([recipe.title, recipe.description ?? ""]
                    + recipe.ingredients.flatMap { $0.items }
                    + recipe.directions.map { $0.text })
            .joined(separator: " ")
            .lowercased()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }

        func hits(_ words: [String]) -> Int {
            words.reduce(0) { $0 + (text.range(of: "\\b\($1)", options: .regularExpression) != nil ? 1 : 0) }
        }
        let cookingVerbs = ["cook","bake","fry","boil","simmer","roast","grill","saute","sauté","stir",
            "mix","whisk","knead","chop","dice","mince","slice","marinate","season","garnish","serve",
            "preheat","heat","blend","fold","drain","steam","toss","spread","pour","add","cut","cover"]
        let units = ["cup","cups","tbsp","tablespoon","tsp","teaspoon","gram","grams","kg","ml","litre",
            "liter","oz","ounce","pound","clove","cloves","pinch"]
        let foods = ["salt","sugar","oil","butter","ghee","flour","egg","eggs","milk","water","onion",
            "garlic","ginger","tomato","chicken","mutton","paneer","rice","cheese","sauce","pepper",
            "spice","masala","cream","dough","batter","paste","chilli","chili","cumin","turmeric",
            "lemon","yogurt","curd","dal","lentil","bean","potato","carrot","coriander","vegetable"]

        let verbHits = hits(cookingVerbs), unitHits = hits(units), foodHits = hits(foods)
        return (verbHits >= 1 && foodHits >= 1) || unitHits >= 1 || foodHits >= 2
    }

    // MARK: - Foundation Models (guided generation)

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    @Generable
    struct GRecipe {
        @Guide(description: "A concise recipe title, 3–6 words.")
        var title: String
        @Guide(description: "Ingredient groups. Use a single group with an empty name when the recipe isn't grouped.")
        var groups: [GGroup]
        @Guide(description: "The cooking steps in order, imperative voice, no numbering.")
        var steps: [String]
    }

    @available(iOS 26, *)
    @Generable
    struct GGroup {
        @Guide(description: "A section label like \"Sauce\" or \"Marinade\", or an empty string. Never a quantity or an ingredient line.")
        var name: String
        @Guide(description: "Ingredient lines with quantities, e.g. \"200g paneer\", \"1 tbsp oil\". Never hashtags or social-tag lists.")
        var items: [String]
    }

    @available(iOS 26, *)
    private static func generate(transcript: String, caption: String?, onScreenText: String?,
                                ownerId: String, sourceLanguage: String?,
                                targetLanguage: AppLanguage?) async throws -> Recipe {
        // Translate in the same pass: title, group names, ingredient items and step texts all come
        // out in targetLanguage. Numbers, quantities and units stay unchanged (200g stays 200g).
        var languageRule = ""
        if let target = targetLanguage,
           let src = sourceLanguage.flatMap({ AppLanguage.from(code: $0) }),
           src != target {
            languageRule = """

            Write ALL user-facing text (title, group names, ingredient items, steps) in \(target.name)
            (\(target.nativeName)). Keep numbers, quantities and units unchanged (e.g. "200g", "1 tbsp",
            "8 min" stay the same). Translate ingredient names and cooking verbs; do not transliterate.
            """
        } else if let target = targetLanguage, sourceLanguage == nil {
            // No detected source (silent / caption-only). Still deliver in the user's chosen language.
            languageRule = """

            Write ALL user-facing text in \(target.name) (\(target.nativeName)). Keep numbers, quantities
            and units unchanged (e.g. "200g", "1 tbsp"). Translate ingredient names and cooking verbs.
            """
        }
        let session = LanguageModelSession(instructions: """
        You convert a cooking video into a clean, structured recipe. Your sources are the spoken
        transcript, the caption, and the ON-SCREEN TEXT read off the video frames — any of them may
        be empty. On-screen text is often the ingredient list and step captions, so use it fully.
        Only include ingredients and steps that actually appear in the sources. Keep quantities and
        units. Ignore hashtags and parenthetical tag lists at the end of a caption. Never invent
        ingredients, amounts, or
        steps that aren't in the source.\(languageRule)
        """)
        var prompt = "Extract the recipe.\n"
        if let caption, !caption.isEmpty { prompt += "CAPTION:\n\(caption)\n\n" }
        if let onScreenText, !onScreenText.isEmpty { prompt += "ON-SCREEN TEXT:\n\(onScreenText)\n\n" }
        prompt += "TRANSCRIPT:\n\(transcript)"

        let g = try await session.respond(to: prompt, generating: GRecipe.self).content
        let ingredients = g.groups
            .map { IngredientGroup(groupName: $0.name.isEmpty ? nil : $0.name,
                                   items: $0.items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) }
            .filter { !$0.items.isEmpty }
        let steps = g.steps
            .map { Self.clean($0) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { DirectionStep(stepIndex: $0.offset + 1, text: $0.element) }

        return Recipe(
            id: UUID().uuidString, ownerId: ownerId,
            title: g.title.isEmpty ? "Imported Recipe" : g.title,
            servings: 2, ingredients: ingredients, directions: steps,
            ownerUsername: "@you", sourceLanguage: sourceLanguage
        )
    }
    #endif

    // MARK: - Heuristic fallback (no on-device LLM)

    private static func heuristic(transcript: String, caption: String?, onScreenText: String?,
                                 ownerId: String, sourceLanguage: String?) -> Recipe {
        let text = [caption, onScreenText, transcript].compactMap { $0 }.joined(separator: "\n")

        // Ingredients: lines that carry a quantity + unit (works well on OCR'd overlays).
        let ingredientItems = ingredientLines(from: text)
        let ingredients = ingredientItems.isEmpty
            ? []
            : [IngredientGroup(groupName: "Main Ingredients", items: ingredientItems)]

        // Steps: sentence-ish fragments, minus the lines we already took as ingredients.
        let ingredientSet = Set(ingredientItems.map { $0.lowercased() })
        let sentences = text
            .split(whereSeparator: { ".!?\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 8 && !ingredientSet.contains($0.lowercased()) }
        let steps = sentences.prefix(14).enumerated()
            .map { DirectionStep(stepIndex: $0.offset + 1, text: Self.clean(String($0.element))) }

        let title = NutritionEstimator.dishTitle(in: text) ?? "Imported Recipe"

        return Recipe(
            id: UUID().uuidString, ownerId: ownerId,
            title: title, servings: 2,
            ingredients: ingredients, directions: Array(steps),
            ownerUsername: "@you", sourceLanguage: sourceLanguage
        )
    }

    /// A caption line that states kcal and all three macros per serving is the chart.
    /// It replaces an ingredient estimate. A kcal-only headline is not the dish title.
    private static func applyingCaptionNutrition(_ recipe: Recipe, caption: String?, onScreenText: String?) -> Recipe {
        let source = [caption, onScreenText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        guard !source.isEmpty else { return recipe }
        var out = recipe
        if let stated = NutritionEstimator.statedPerServing(in: source) {
            out.nutrition = stated
        }
        if NutritionEstimator.isKcalServingHeadline(out.title),
           let dish = NutritionEstimator.dishTitle(in: source) {
            out.title = dish
        }
        return out
    }

    /// Clean a direction string: tidy whitespace and collapse HALLUCINATED REPETITIONS. Whisper on
    /// music/silence often emits runs like "mix mix mix mix mix…"; the LLM sometimes doesn't fix
    /// them. We collapse any word repeated 3+ times in a row (case-insensitive) to a single
    /// occurrence, and cap the step at 400 chars so even an unsalvageable hallucination can't fill
    /// the card.
    static func clean(_ text: String) -> String {
        let normalised = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalised.isEmpty,
              let re = try? NSRegularExpression(pattern: #"\b(\w+)(?:\s+\1\b){2,}"#, options: [.caseInsensitive])
        else { return normalised }
        let full = NSRange(normalised.startIndex..., in: normalised)
        let collapsed = re.stringByReplacingMatches(in: normalised, range: full, withTemplate: "$1")
        return String(collapsed.prefix(400))
    }

    /// Lines that look like an ingredient (quantity + unit), de-duplicated. For OCR/caption text.
    private static func ingredientLines(from text: String) -> [String] {
        let pattern = #"(?i)\b(\d+([.,/]\d+)?|½|¼|¾|⅓|⅔)\s*(g|kg|mg|ml|l|oz|lb|lbs|cup|cups|tbsp|tbs|tablespoons?|tsp|teaspoons?|cloves?|slices?|cans?|pinch|sticks?|eggs?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var out: [String] = []
        var seen = Set<String>()
        for raw in text.split(whereSeparator: { "\n".contains($0) }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.count >= 3, line.count <= 70 else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard regex.firstMatch(in: line, options: [], range: range) != nil else { continue }
            let key = line.lowercased()
            if !seen.contains(key) { seen.insert(key); out.append(line) }
        }
        return out
    }
}
