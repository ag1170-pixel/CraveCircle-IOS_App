//
//  AppStorage+RecipeLanguage.swift
//  CraveCircle (AICookBook)
//
//  Convenience @AppStorage binding for the preferred recipe language.
//

import SwiftUI

extension AppStorage where Value == String {
    init(recipeLanguage _: Void = ()) {
        self.init(wrappedValue: LanguagePrefs.default.rawValue, LanguagePrefs.key)
    }
}
