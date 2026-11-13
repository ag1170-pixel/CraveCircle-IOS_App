//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: View+DoodleBackground.swift
// ==============================================================================
//
// 1. PURPOSE:
//    SwiftUI presentation component managing the View+DoodleBackground user interface.
//
// 2. ARCHITECTURAL ROLE:
//    Renders UI layouts, binds to AppEnvironment state, and handles user interactions.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "View+DoodleBackground is a SwiftUI view responsible for rendering this section of the app and communicating user actions to AppEnvironment."
//
// ==============================================================================
//

//
//  View+DoodleBackground.swift
//  CraveCircle (AICookBook)
//
//  Attach the static food-doodle wallpaper behind a screen's content.
//

import SwiftUI

extension View {
    /// Static food-doodle wallpaper behind this screen's content.
    func doodleScreenBackground() -> some View {
        background(AppScreenBackground(doodle: true))
    }
}
