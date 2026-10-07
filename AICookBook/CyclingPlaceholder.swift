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
    var prefix: String = ""        // static lead-in that never animates, e.g. "Search for "
    let phrases: [String]          // the cycling terms (the only part that moves)
    var quoted: Bool = true        // wrap each term in single quotes → Search for 'pasta'
    var font: Font = AppFont.body(16)
    var color: Color = AppTheme.textTertiary
    var interval: TimeInterval = 2.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private func term(_ s: String) -> String { quoted ? "'\(s)'" : s }

    var body: some View {
        // Prefix is static; only the term view gets a new identity each tick, so just it rises/fades.
        HStack(spacing: 0) {
            if !prefix.isEmpty { Text(prefix) }
            Group {
                if reduceMotion || phrases.count <= 1 {
                    Text(term(phrases.first ?? ""))
                } else {
                    Text(term(phrases[index % phrases.count]))
                        .id(index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
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
    CyclingPlaceholder(prefix: "Search for ", phrases: ["pasta", "cake", "paneer"])
        .padding()
}
