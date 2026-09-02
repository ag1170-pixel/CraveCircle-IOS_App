//
//  IngredientScaler.swift
//  CraveCircle (AICookBook)
//
//  Scales ingredient amounts and nutrition values dynamically based on target servings.
//

import Foundation

enum IngredientScaler {
    /// Scale an ingredient string from baseServings to targetServings.
    static func scale(text: String, from baseServings: Int, to targetServings: Int) -> String {
        let base = max(baseServings, 1)
        let target = max(targetServings, 1)
        guard base != target else { return text }

        let ratio = Double(target) / Double(base)
        var result = text

        // 1. Check for mixed fraction at the start: e.g. "1 1/2 cups"
        if let mixedMatch = matchRegex(pattern: #"^(\d+)\s+(\d+)/(\d+)\b"#, in: result) {
            if let whole = Double(mixedMatch[1]),
               let num = Double(mixedMatch[2]),
               let den = Double(mixedMatch[3]), den != 0 {
                let originalValue = whole + (num / den)
                let scaledValue = originalValue * ratio
                let formatted = formatQuantity(scaledValue)
                result = replaceFirst(pattern: #"^(\d+)\s+(\d+)/(\d+)\b"#, in: result, with: formatted)
                return scaleParenthetical(result, ratio: ratio)
            }
        }

        // 2. Check for simple fraction at the start: e.g. "1/2 cup" or "3/4 tsp"
        if let fracMatch = matchRegex(pattern: #"^(\d+)/(\d+)\b"#, in: result) {
            if let num = Double(fracMatch[1]),
               let den = Double(fracMatch[2]), den != 0 {
                let originalValue = num / den
                let scaledValue = originalValue * ratio
                let formatted = formatQuantity(scaledValue)
                result = replaceFirst(pattern: #"^(\d+)/(\d+)\b"#, in: result, with: formatted)
                return scaleParenthetical(result, ratio: ratio)
            }
        }

        // 3. Check for attached unit numbers: e.g. "240ml", "120g", "250g", "700g"
        if let attachedMatch = matchRegex(pattern: #"^(\d+(?:\.\d+)?)(ml|g|kg|l|oz|lbs?)\b"#, in: result) {
            if let val = Double(attachedMatch[1]) {
                let unit = attachedMatch[2]
                let scaledVal = (val * ratio).rounded()
                let formatted = "\(Int(scaledVal))\(unit)"
                result = replaceFirst(pattern: #"^(\d+(?:\.\d+)?)(ml|g|kg|l|oz|lbs?)\b"#, in: result, with: formatted)
                return scaleParenthetical(result, ratio: ratio)
            }
        }

        // 4. Check for standard leading decimal or integer: e.g. "2 large chicken breasts", "1.5 lbs", "1 tbsp"
        if let numMatch = matchRegex(pattern: #"^(\d+(?:\.\d+)?)\b"#, in: result) {
            if let val = Double(numMatch[1]) {
                let scaledVal = val * ratio
                let formatted = formatQuantity(scaledVal)
                result = replaceFirst(pattern: #"^(\d+(?:\.\d+)?)\b"#, in: result, with: formatted)
                return scaleParenthetical(result, ratio: ratio)
            }
        }

        return scaleParenthetical(result, ratio: ratio)
    }

    /// Scales parenthetical gram/ml amounts like "(approx. 450g)" or "(400g)" or "(180g each)"
    private static func scaleParenthetical(_ text: String, ratio: Double) -> String {
        guard let match = matchRegex(pattern: #"\(([^)]*?)(\d+(?:\.\d+)?)\s*(g|ml)([^)]*?)\)"#, in: text) else {
            return text
        }
        if let val = Double(match[2]) {
            let prefix = match[1]
            let unit = match[3]
            let suffix = match[4]
            let scaled = Int((val * ratio).rounded())
            let replacement = "(\(prefix)\(scaled)\(unit)\(suffix))"
            return replaceFirst(pattern: #"\(([^)]*?)(\d+(?:\.\d+)?)\s*(g|ml)([^)]*?)\)"#, in: text, with: replacement)
        }
        return text
    }

    /// Format a scaled numeric quantity into a human-friendly cooking representation
    private static func formatQuantity(_ val: Double) -> String {
        let tolerance = 0.05

        // Near whole numbers
        let rounded = val.rounded()
        if abs(val - rounded) < tolerance {
            return "\(Int(rounded))"
        }

        let whole = Int(val.rounded(.down))
        let frac = val - Double(whole)

        var fracStr = ""
        if abs(frac - 0.5) < tolerance {
            fracStr = "1/2"
        } else if abs(frac - 0.25) < tolerance {
            fracStr = "1/4"
        } else if abs(frac - 0.75) < tolerance {
            fracStr = "3/4"
        } else if abs(frac - (1.0/3.0)) < tolerance {
            fracStr = "1/3"
        } else if abs(frac - (2.0/3.0)) < tolerance {
            fracStr = "2/3"
        } else if abs(frac - 0.125) < tolerance {
            fracStr = "1/8"
        } else {
            // Decimal format
            if val < 10 {
                return String(format: "%.1f", val)
            } else {
                return "\(Int(round(val)))"
            }
        }

        if whole == 0 {
            return fracStr
        } else {
            return "\(whole) \(fracStr)"
        }
    }

    // MARK: - Regex Helpers

    private static func matchRegex(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }

        var results: [String] = []
        for i in 0..<match.numberOfRanges {
            let range = match.range(at: i)
            if range.location != NSNotFound {
                results.append(nsString.substring(with: range))
            } else {
                results.append("")
            }
        }
        return results
    }

    private static func replaceFirst(pattern: String, in text: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let first = regex.firstMatch(in: text, options: [], range: range) else {
            return text
        }
        return (nsString as NSString).replacingCharacters(in: first.range, with: replacement)
    }
}
