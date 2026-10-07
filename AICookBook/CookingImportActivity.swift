//
//  CookingImportActivity.swift
//  CraveCircle (AICookBook)
//
//  Shared ActivityKit model for the "recipe cooking" Live Activity (Dynamic Island + Lock Screen).
//  Added to BOTH the app target (which starts/updates/ends the activity) and the widget extension
//  (which renders it). Mirrors the app's ImportFlowState so there's one source of truth.
//

import Foundation
import ActivityKit

struct CookingImportAttributes: ActivityAttributes {
    /// When the import started — used to drive the self-filling buffer bar.
    var startedAt: Date

    public struct ContentState: Codable, Hashable {
        enum Stage: String, Codable, Hashable {
            case downloading, transcribing, extracting, done, failed

            /// Short, friendly label (matches the in-app import toast copy).
            var label: String {
                switch self {
                case .downloading:  return "Grabbing the reel…"
                case .transcribing: return "Listening to the video…"
                case .extracting:   return "Writing your recipe…"
                case .done:         return "Recipe ready — tap to open"
                case .failed:       return "Import didn't finish"
                }
            }

            /// SF Symbol fallback glyph per stage (used until the Gemini art frames are added).
            var symbol: String {
                switch self {
                case .downloading:  return "arrow.down.circle"
                case .transcribing: return "waveform"
                case .extracting:   return "text.append"
                case .done:         return "checkmark.seal.fill"
                case .failed:       return "exclamationmark.triangle.fill"
                }
            }

            var isTerminal: Bool { self == .done || self == .failed }
        }

        var stage: Stage
        var recipeTitle: String        // "New recipe" until the title is known
        var recipeId: String?          // set on .done → deep-link target
        /// When the buffer bar should read "full". An estimate while cooking; snapped to now on done.
        var estimatedEnd: Date
        var message: String?           // failure reason, if any
    }
}
