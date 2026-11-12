//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: View+SectionLabel.swift
// ==============================================================================
//
// 1. PURPOSE:
//    SwiftUI presentation component managing the View+SectionLabel user interface.
//
// 2. ARCHITECTURAL ROLE:
//    Renders UI layouts, binds to AppEnvironment state, and handles user interactions.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "View+SectionLabel is a SwiftUI view responsible for rendering this section of the app and communicating user actions to AppEnvironment."
//
// ==============================================================================
//

//
//  View+SectionLabel.swift
//  CraveCircle (AICookBook)
//
//  The small uppercase section-label style used above content groups.
//

import SwiftUI

extension View {
    func sectionLabelStyle(_ color: Color = AppTheme.textSecondary) -> some View {
        self.font(AppFont.label(13, weight: .semibold))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
