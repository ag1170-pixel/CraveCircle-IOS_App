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
