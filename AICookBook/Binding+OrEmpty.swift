//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: Binding+OrEmpty.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Supporting utility and business logic for Binding+OrEmpty.
//
// 2. ARCHITECTURAL ROLE:
//    Provides specialized helper functions, algorithms, or extensions for the CraveCircle ecosystem.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "Binding+OrEmpty encapsulates focused domain logic and helper utilities used across the project."
//
// ==============================================================================
//

//
//  Binding+OrEmpty.swift
//  CraveCircle (AICookBook)
//
//  Bridge an optional-String model field to a plain-String binding for TextFields.
//

import SwiftUI

extension Binding where Value == String? {
    /// Bridge an optional-string model field to a plain-string TextField.
    func orEmpty() -> Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
