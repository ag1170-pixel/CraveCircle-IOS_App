//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: AppStorage+RecipeLanguage.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Supporting utility and business logic for AppStorage+RecipeLanguage.
//
// 2. ARCHITECTURAL ROLE:
//    Provides specialized helper functions, algorithms, or extensions for the CraveCircle ecosystem.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "AppStorage+RecipeLanguage encapsulates focused domain logic and helper utilities used across the project."
//
// ==============================================================================
//

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
