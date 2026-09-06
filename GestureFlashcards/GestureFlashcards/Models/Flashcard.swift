import Foundation

/// A flashcard is just a number here — this app is about navigating a deck by
/// hand, not reading gestures. Swap the deck for whatever content you want.
struct Flashcard: Identifiable, Equatable {
    let id = UUID()
    let number: Int
}

extension Flashcard {
    /// Cards numbered 1…count.
    static func numbered(_ count: Int = 20) -> [Flashcard] {
        (1...count).map { Flashcard(number: $0) }
    }
}
