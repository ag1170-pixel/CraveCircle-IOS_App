import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var camera = CameraManager()
    private let detector = SwipeDetector()

    @State private var deck = Flashcard.numbered(20)
    @State private var index = 0
    @State private var slideForward = true
    @State private var flashDirection: SwipeDirection?

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.12).ignoresSafeArea()

            VStack(spacing: 16) {
                header

                Spacer(minLength: 0)

                // Card with directional slide transition.
                FlashcardView(card: deck[index], total: deck.count)
                    .id(deck[index].id)
                    .transition(.asymmetric(
                        insertion: .move(edge: slideForward ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: slideForward ? .leading : .trailing).combined(with: .opacity)))

                Spacer(minLength: 0)

                progressDots
                Text(camera.statusText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 8)
            }

            // Camera preview + skeleton, pinned bottom-trailing.
            cameraPip
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(20)

            // Big directional flash when a swipe fires.
            if let dir = flashDirection {
                Image(systemName: dir == .right ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        // Run the swipe detector on each new hand reading.
        .onChange(of: camera.hand) { newHand in
            if let dir = detector.update(hand: newHand) {
                navigate(dir)
            }
        }
        // Manual swipe fallback (also handy for testing without a hand).
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 { navigate(.left) }
                    else if value.translation.width > 40 { navigate(.right) }
                }
        )
    }

    // MARK: Subviews

    private var header: some View {
        HStack {
            Text("Gesture Flashcards")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Label(camera.isRunning ? "Live" : "Off",
                  systemImage: "dot.radiowaves.left.and.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(camera.isRunning ? .green : .gray)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(deck.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.white : Color.white.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var cameraPip: some View {
        ZStack {
            if camera.isRunning {
                CameraPreview(session: camera.session)
                if let hand = camera.hand {
                    HandSkeletonOverlay(points: hand.points, isOpenPalm: hand.isOpenPalm)
                }
            } else {
                Color.black
            }
        }
        .frame(width: 120, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke((camera.hand?.isOpenPalm ?? false) ? Color.green : Color.white.opacity(0.3),
                        lineWidth: 2)
        )
    }

    // MARK: Navigation

    private func navigate(_ dir: SwipeDirection) {
        // Clamp at the ends so direction stays unambiguous (no wrap-around).
        let target = dir == .right ? index + 1 : index - 1
        guard target >= 0, target < deck.count else { return }

        slideForward = (dir == .right)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            index = target
        }
        showFlash(dir)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func showFlash(_ dir: SwipeDirection) {
        withAnimation(.easeOut(duration: 0.15)) { flashDirection = dir }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.25)) { flashDirection = nil }
        }
    }
}

#Preview {
    ContentView()
}
