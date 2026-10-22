//
//  WebRecipe.swift
//  CraveCircle (AICookBook)
//
//  Read the recipe a food site already publishes (schema.org Recipe) and save it on this phone.
//  Google is only the search page. The scrape is the page the person opens.
//

import Foundation

enum WebRecipeParser {
    static func isSearchHost(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        if host == "google.com" || host.hasSuffix(".google.com") { return true }
        return host.hasPrefix("google.") || host.contains(".google.")
    }

    static func recipe(html: String, pageURL: URL, ownerId: String) -> Recipe? {
        let pattern = "(?is)<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        var blocks: [String] = []
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let match, match.numberOfRanges > 1, let span = Range(match.range(at: 1), in: html) else { return }
            blocks.append(String(html[span]))
        }
        return recipe(blocks: blocks, pageURL: pageURL, ownerId: ownerId, pageImage: openGraphImage(html))
    }

    static func recipe(blocks: [String], pageURL: URL, ownerId: String, pageImage: String? = nil) -> Recipe? {
        if isSearchHost(pageURL) { return nil }
        for block in blocks {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            var budget = 400
            guard let node = findRecipe(json, budget: &budget) else { continue }
            if let recipe = make(node, pageURL: pageURL, ownerId: ownerId, pageImage: pageImage) { return recipe }
        }
        return nil
    }

    /// Stop after a few hundred nodes. A food page's recipe sits near the top; the rest is site junk.
    private static func findRecipe(_ value: Any, budget: inout Int) -> [String: Any]? {
        budget -= 1
        if budget < 0 { return nil }
        if let dict = value as? [String: Any] {
            if isRecipe(dict["@type"]) { return dict }
            if let graph = dict["@graph"], let found = findRecipe(graph, budget: &budget) { return found }
            for (key, nested) in dict where key != "@context" && key != "@id" {
                if let found = findRecipe(nested, budget: &budget) { return found }
            }
        } else if let list = value as? [Any] {
            for item in list.prefix(40) {
                if let found = findRecipe(item, budget: &budget) { return found }
            }
        }
        return nil
    }

    private static func isRecipe(_ value: Any?) -> Bool {
        let names: [String]
        if let one = value as? String { names = [one] }
        else if let many = value as? [String] { names = many }
        else { return false }
        return names.contains { $0 == "Recipe" || $0.hasSuffix("/Recipe") }
    }

    private static func openGraphImage(_ html: String) -> String? {
        let patterns = [
            "(?i)<meta[^>]*property=[\"']og:image[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "(?i)<meta[^>]*content=[\"']([^\"']+)[\"'][^>]*property=[\"']og:image[\"']"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  match.numberOfRanges > 1, let span = Range(match.range(at: 1), in: html) else { continue }
            return String(html[span])
        }
        return nil
    }

    private static func make(_ node: [String: Any], pageURL: URL, ownerId: String, pageImage: String?) -> Recipe? {
        let title = plain(string(node["name"])).trimmingCharacters(in: .whitespacesAndNewlines)
        let items = ingredients(node["recipeIngredient"])
        let steps = instructions(node["recipeInstructions"])
        guard !title.isEmpty, !items.isEmpty || !steps.isEmpty else { return nil }
        let host = pageURL.host?.replacingOccurrences(of: "www.", with: "") ?? "web"
        return Recipe(
            id: "web-\(UUID().uuidString.prefix(8))",
            ownerId: ownerId,
            title: title,
            description: plain(string(node["description"])).nilIfEmpty,
            prepTime: nil,
            cookTime: duration(node["cookTime"] ?? node["totalTime"]),
            servings: yieldCount(node["recipeYield"]),
            ingredients: [IngredientGroup(groupName: nil, items: items)],
            directions: steps.enumerated().map { DirectionStep(stepIndex: $0.offset + 1, text: $0.element) },
            thumbnailUrl: resolvedImage(imageURL(node["image"]) ?? pageImage, page: pageURL),
            ownerUsername: host,
            sourceUrl: pageURL.absoluteString,
            visibility: .followers
        )
    }

    private static func ingredients(_ value: Any?) -> [String] {
        let raw: [String]
        if let list = value as? [Any] { raw = list.compactMap(string) }
        else if let one = string(value) { raw = [one] }
        else { raw = [] }
        var seen = Set<String>()
        return raw.compactMap { line in
            let clean = IngredientListFormat.cookLine(plain(line))
            guard clean.count >= 2 else { return nil }
            let key = clean.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return clean
        }
    }

    private static func instructions(_ value: Any?) -> [String] {
        var out: [String] = []
        collectSteps(value, into: &out)
        var seen = Set<String>()
        return out.filter { seen.insert($0.lowercased()).inserted }
    }

    private static func collectSteps(_ value: Any?, into out: inout [String]) {
        if let text = value as? String {
            for line in plain(text).components(separatedBy: .newlines) {
                let step = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if step.count >= 2 { out.append(step) }
            }
        } else if let list = value as? [Any] {
            for item in list { collectSteps(item, into: &out) }
        } else if let dict = value as? [String: Any] {
            if let nested = dict["itemListElement"] {
                collectSteps(nested, into: &out)
            } else if let text = string(dict["text"]) ?? string(dict["name"]) {
                let step = plain(text).trimmingCharacters(in: .whitespacesAndNewlines)
                if step.count >= 2 { out.append(step) }
            }
        }
    }

    private static func yieldCount(_ value: Any?) -> Int? {
        if let number = value as? Int, number > 0 { return number }
        if let number = value as? Double, number > 0 { return Int(number) }
        if let list = value as? [Any] { return yieldCount(list.first) }
        guard let text = string(value) else { return nil }
        let digits = text.split(whereSeparator: { !$0.isNumber })
        return digits.first.flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }
    }

    private static func duration(_ value: Any?) -> String? {
        guard let text = string(value)?.uppercased(), text.hasPrefix("PT") else { return nil }
        var hours = 0, minutes = 0
        if let h = text.range(of: #"(\d+)H"#, options: .regularExpression) {
            hours = Int(text[h].dropLast()) ?? 0
        }
        if let m = text.range(of: #"(\d+)M"#, options: .regularExpression) {
            minutes = Int(text[m].dropLast()) ?? 0
        }
        let total = hours * 60 + minutes
        guard total > 0 else { return nil }
        return Recipe.formatMinutes(total)
    }

    private static func imageURL(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let list = value as? [Any] {
            for item in list {
                if let found = imageURL(item) { return found }
            }
        }
        if let dict = value as? [String: Any] {
            return imageURL(dict["url"] ?? dict["contentUrl"] ?? dict["@id"])
        }
        return nil
    }

    private static func resolvedImage(_ raw: String?, page: URL) -> String? {
        guard var raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("//") { raw = "https:" + raw }
        guard let url = URL(string: raw, relativeTo: page)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url.absoluteString
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func plain(_ text: String?) -> String {
        guard let text else { return "" }
        var out = text
            .replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "(?i)</p>|</li>|<li[^>]*>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&nbsp;": " ", "&#39;": "'", "&quot;": "\"", "&lt;": "<", "&gt;": ">"]
        for (entity, mark) in entities { out = out.replacingOccurrences(of: entity, with: mark) }
        return out.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
