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
    static func extract(transcript: String, caption: String?, ownerId: String,
                        sourceLanguage: String?, onScreenText: String? = nil) async -> Recipe {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), case .available = SystemLanguageModel.default.availability {
            if let recipe = try? await generate(transcript: transcript, caption: caption,
                                                onScreenText: onScreenText,
                                                ownerId: ownerId, sourceLanguage: sourceLanguage) {
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
                                ownerId: String, sourceLanguage: String?) async throws -> Recipe {
        let session = LanguageModelSession(instructions: """
        You convert a cooking video into a clean, structured recipe. Your sources are the spoken
        transcript, the caption, and the ON-SCREEN TEXT read off the video frames — any of them may
        be empty. On-screen text is often the ingredient list and step captions, so use it fully.
        Only include ingredients and steps that actually appear in the sources. Keep quantities and
        units. Never invent ingredients, amounts, or steps that aren't in the source.
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
        // Structure comes from the caption / on-screen text (they're line-based lists). The spoken
        // transcript is only mined for extra cooking steps, never dumped verbatim.
        let structured = [caption, onScreenText].compactMap { $0 }.joined(separator: "\n")
        let lines = structured
            .split(whereSeparator: { "\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var groups: [IngredientGroup] = []
        var currentGroupName: String? = nil
        var currentItems: [String] = []
        var stepLines: [String] = []
        var titleCandidate: String?

        func flush() {
            if !currentItems.isEmpty {
                groups.append(IngredientGroup(groupName: currentGroupName, items: currentItems))
                currentItems = []
            }
        }

        for line in lines {
            if isHashtagOrJunk(line) { continue }
            if titleCandidate == nil, line.count >= 3, !looksLikeIngredient(line), !looksLikeStep(line),
               !isSectionHeader(line) {
                titleCandidate = String(line.prefix(48))     // first real non-list line = title
            }
            if isSectionHeader(line) {
                flush()
                // Ingredient-section headers ("For Fried Noodles", "Sauce") group the items under them;
                // step-section headers ("Method", "Steps") just get dropped (steps detected by verb).
                currentGroupName = isStepSectionHeader(line) ? nil : cleanedHeader(line)
                continue
            }
            if looksLikeIngredient(line) {
                currentItems.append(line)
            } else if looksLikeStep(line) {
                stepLines.append(line)
            }
            // else: skip filler / non-recipe noise entirely.
        }
        flush()

        // If the caption gave few steps, mine the spoken transcript for genuine cooking sentences.
        if stepLines.count < 2, !transcript.isEmpty {
            let spoken = transcript
                .split(whereSeparator: { ".!?\n".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 12 && looksLikeStep($0) && !isHashtagOrJunk($0) }
            stepLines.append(contentsOf: spoken)
        }

        // De-dupe steps, cap length.
        var seenSteps = Set<String>()
        let steps = stepLines
            .filter { seenSteps.insert($0.lowercased()).inserted }
            .prefix(20).enumerated()
            .map { DirectionStep(stepIndex: $0.offset + 1, text: String($0.element)) }

        return Recipe(
            id: UUID().uuidString, ownerId: ownerId,
            title: titleCandidate ?? "Imported Recipe", servings: 2,
            ingredients: groups, directions: Array(steps),
            ownerUsername: "@you", sourceLanguage: sourceLanguage
        )
    }

    // MARK: Line classification (keeps ingredients / steps / noise apart)

    private static let cookingVerbs: Set<String> = [
        "heat","add","cook","fry","stir","mix","pour","chop","dice","boil","saute","sauté","simmer",
        "cover","garnish","serve","blend","whisk","knead","marinate","bake","roast","grill","toss",
        "drain","season","sprinkle","combine","transfer","remove","cut","slice","grind","soak","fold",
        "spread","layer","flip","cool","rest","set","prepare","make","keep","put","take","boil","fry",
        "deep","shallow","temper","garnish","refrigerate","chill","strain","beat","crush","peel","wash",
        "melt","preheat","bring","reduce","coat","dip","assemble","top","squeeze","brush","drizzle"]

    /// A hashtag line, a mostly-hashtag line, or obvious non-recipe filler (promo/CTA/emoji-only).
    private static func isHashtagOrJunk(_ line: String) -> Bool {
        let l = line.lowercased()
        if line.hasPrefix("#") || line.filter({ $0 == "#" }).count >= 2 { return true }
        let junk = ["follow", "like and", "subscribe", "comment", "link in bio", "reelinstagram",
                    "fyp", "explore", "viral", "trending", "share this", "save this", "dm ", "click"]
        if junk.contains(where: { l.contains($0) }) && !looksLikeStep(line) { return true }
        // Lines with no letters (emoji/symbols only).
        if line.range(of: #"[A-Za-zऀ-ॿ]"#, options: .regularExpression) == nil { return true }
        return false
    }

    /// "Ingredients:", "For the sauce", "Method", "Steps", "For Fried Noodles" — a section label,
    /// not an ingredient or a step. Short, no trailing quantity, often starts with "For" or ends ":".
    private static func isSectionHeader(_ line: String) -> Bool {
        let l = line.lowercased()
        if l.hasSuffix(":") && line.count <= 40 { return true }
        if l.hasPrefix("for ") && line.count <= 40 && !looksLikeIngredient(line) { return true }
        let headers = ["ingredients", "method", "steps", "directions", "instructions", "recipe",
                       "for garnish", "for serving", "to serve", "notes"]
        return headers.contains(where: { l == $0 || l.hasPrefix($0) }) && line.count <= 40
    }

    private static func isStepSectionHeader(_ line: String) -> Bool {
        let l = line.lowercased()
        return ["method", "steps", "directions", "instructions"].contains(where: { l.hasPrefix($0) })
    }

    private static func cleanedHeader(_ line: String) -> String {
        line.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Ingredient line: carries a quantity/unit, OR is a "name - amount" list entry, OR a bare
    /// pantry line ("few", "to taste", "for frying"). Bounded length; not a cooking instruction.
    private static func looksLikeIngredient(_ line: String) -> Bool {
        guard line.count >= 2, line.count <= 80 else { return false }
        if looksLikeStep(line) { return false }
        let qty = #"(?i)(\b\d+([.,/]\d+)?\b|½|¼|¾|⅓|⅔)\s*(g|gm|gms|gram|grams|kg|mg|ml|l|litre|oz|lb|lbs|cup|cups|tbsp|tbs|tablespoons?|tsp|teaspoons?|clove|cloves|slice|slices|can|cans|pinch|stick|sticks|egg|eggs|packet|packets|piece|pieces|inch|handful)\b"#
        if line.range(of: qty, options: .regularExpression) != nil { return true }
        // "Onion - 1/2 (finely chopped)", "Coriander leaves - few", "Hakka noodles - 1 small packet"
        if line.range(of: #"\s[-–—]\s"#, options: .regularExpression) != nil { return true }
        let pantry = ["to taste", "for frying", "for garnish", "as required", "as needed"]
        if pantry.contains(where: { line.lowercased().contains($0) }) { return true }
        return false
    }

    /// Step line: an imperative cooking instruction (starts with / contains a cooking verb).
    private static func looksLikeStep(_ line: String) -> Bool {
        let words = line.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard let first = words.first else { return false }
        if cookingVerbs.contains(first) { return true }             // imperative opener
        // A cooking verb early in a longer instruction sentence.
        if words.count >= 4 && words.prefix(3).contains(where: { cookingVerbs.contains($0) }) { return true }
        return false
    }
}
