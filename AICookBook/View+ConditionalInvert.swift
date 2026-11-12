//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: View+ConditionalInvert.swift
// ==============================================================================
//
// 1. PURPOSE:
//    SwiftUI presentation component managing the View+ConditionalInvert user interface.
//
// 2. ARCHITECTURAL ROLE:
//    Renders UI layouts, binds to AppEnvironment state, and handles user interactions.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "View+ConditionalInvert is a SwiftUI view responsible for rendering this section of the app and communicating user actions to AppEnvironment."
//
// ==============================================================================
//

//
//  View+ConditionalInvert.swift
//  CraveCircle (AICookBook)
//
//  Apply `.colorInvert()` only when a condition holds, keeping a single view branch.
//

import SwiftUI

extension View {
    @ViewBuilder func colorInvert(if condition: Bool) -> some View {
        if condition { self.colorInvert() } else { self }
    }
}
