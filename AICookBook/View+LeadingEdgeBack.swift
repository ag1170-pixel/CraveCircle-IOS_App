//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: View+LeadingEdgeBack.swift
// ==============================================================================
//
// 1. PURPOSE:
//    SwiftUI presentation component managing the View+LeadingEdgeBack user interface.
//
// 2. ARCHITECTURAL ROLE:
//    Renders UI layouts, binds to AppEnvironment state, and handles user interactions.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "View+LeadingEdgeBack is a SwiftUI view responsible for rendering this section of the app and communicating user actions to AppEnvironment."
//
// ==============================================================================
//

//
//  View+LeadingEdgeBack.swift
//  CraveCircle (AICookBook)
//
//  Left-edge swipe-to-go-back gesture (see LeadingEdgeBackModifier in DesignComponents).
//

import SwiftUI

extension View {
    func leadingEdgeBack(_ onBack: @escaping () -> Void) -> some View {
        modifier(LeadingEdgeBackModifier(onBack: onBack))
    }
}
