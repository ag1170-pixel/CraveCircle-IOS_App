//
//  CyclingPlaceholder.swift
//  CraveCircle (AICookBook)
//
//  Swiggy-style search placeholder: hints rise up and fade, one after another, in a
//  lower-emphasis tone. Overlay it on a search field (leading-aligned,
//  `.allowsHitTesting(false)`) and show it only while the field is empty. Shared by the
//  Home search and the Grocery "add item" field. Honors Reduce Motion — then it shows a
//  single static hint and never animates.
//

import SwiftUI

struct CyclingPlaceholder: View {
    let phrases: [String]
    var font: Font = AppFont.body(16)
    var color: Color = AppTheme.textTertiary
    var interval: TimeInterval = 2.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    var body: some View {
        Group {
            if reduceMotion || phrases.count <= 1 {
                Text(phrases.first ?? "")
            } else {
                Text(phrases[index % phrases.count])
                    .id(index)                              // new identity each tick → transition fires
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .font(font)
        .foregroundStyle(color)
        .lineLimit(1)
        // One owned task; auto-cancelled on disappear, so no stacked timer subscriptions.
        .task {
            guard !reduceMotion, phrases.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { index += 1 }
            }
        }
    }
}

#Preview {
    CyclingPlaceholder(phrases: ["Search for cake", "Search for sweet", "Search for pizza"])
        .padding()
}
