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
