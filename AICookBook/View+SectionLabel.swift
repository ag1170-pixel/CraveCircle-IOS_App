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
