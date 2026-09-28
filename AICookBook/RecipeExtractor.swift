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
                return recipe
            }
        }
        #endif
        return heuristic(transcript: transcript, caption: caption, onScreenText: onScreenText,
                         ownerId: ownerId, sourceLanguage: sourceLanguage)
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
        @Guide(description: "A section label like \"Sauce\" or \"Marinade\", or an empty string.")
        var name: String
        @Guide(description: "Ingredient lines with quantities, e.g. \"200g paneer\", \"1 tbsp oil\".")
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
        units. Never invent ingredients, amounts, or steps that aren't in the source.\(languageRule)
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
            .map { $0.trimmingCharacters(in: .whitespaces) }
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
            .map { DirectionStep(stepIndex: $0.offset + 1, text: String($0.element)) }

        let title = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { $0.count >= 3 })
            .map { String($0.prefix(48)) } ?? "Imported Recipe"

        return Recipe(
            id: UUID().uuidString, ownerId: ownerId,
            title: title, servings: 2,
            ingredients: ingredients, directions: Array(steps),
            ownerUsername: "@you", sourceLanguage: sourceLanguage
        )
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
