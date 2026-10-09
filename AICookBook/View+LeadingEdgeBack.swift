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
