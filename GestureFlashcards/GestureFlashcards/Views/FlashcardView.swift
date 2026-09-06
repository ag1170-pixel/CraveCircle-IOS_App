import SwiftUI

struct FlashcardView: View {
    let card: Flashcard
    let total: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("\(card.number)")
                .font(.system(size: 140, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("Card \(card.number) of \(total)")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.18, green: 0.20, blue: 0.40),
                                            Color(red: 0.10, green: 0.11, blue: 0.24)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        )
        .padding(.horizontal, 24)
    }
}
