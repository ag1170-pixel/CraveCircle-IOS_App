//
//  Localization.swift
//  CraveCircle (AICookBook)
//
//  Recipe language preference. A shared reel may be in Hindi, Marathi, etc.; the user
//  picks the language every imported recipe should be delivered in (English or Hindi by
//  default). The server pipeline transcribes the reel audio, detects the source language,
//  and translates the recipe into this language before it's stored. The app owns the
//  preference and shows a "translated from …" note.
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case hindi = "hi"
    case marathi = "mr"
    case tamil = "ta"
    case telugu = "te"
    case bengali = "bn"
    case spanish = "es"
    case french = "fr"

    var id: String { rawValue }

    /// English name of the language.
    var name: String {
        switch self {
        case .english: return "English"
        case .hindi: return "Hindi"
        case .marathi: return "Marathi"
        case .tamil: return "Tamil"
        case .telugu: return "Telugu"
        case .bengali: return "Bengali"
        case .spanish: return "Spanish"
        case .french: return "French"
        }
    }

    /// Endonym — the language's own name.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .hindi: return "हिन्दी"
        case .marathi: return "मराठी"
        case .tamil: return "தமிழ்"
        case .telugu: return "తెలుగు"
        case .bengali: return "বাংলা"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }

    /// BCP-47 locale for on-device speech transcription (Apple SpeechTranscriber).
    var localeID: String {
        switch self {
        case .english: return "en-US"
        case .hindi: return "hi-IN"
        case .marathi: return "mr-IN"
        case .tamil: return "ta-IN"
        case .telugu: return "te-IN"
        case .bengali: return "bn-IN"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        }
    }

    static func from(code: String?) -> AppLanguage? {
        guard let code else { return nil }
        return AppLanguage(rawValue: String(code.prefix(2)).lowercased())
    }

    /// The user's currently-selected preferred language (from settings), or English.
    static var preferred: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: LanguagePrefs.key) ?? "en") ?? .english
    }
}

enum LanguagePrefs {
    static let key = "preferred_recipe_language"
    static let `default` = AppLanguage.english
}

/// Convenience @AppStorage binding for the preferred recipe language.
extension AppStorage where Value == String {
    init(recipeLanguage _: Void = ()) {
        self.init(wrappedValue: LanguagePrefs.default.rawValue, LanguagePrefs.key)
    }
}
