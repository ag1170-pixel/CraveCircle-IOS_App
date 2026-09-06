//
//  FlashcardCookScreen.swift
//  CraveCircle (AICookBook)
//
//  Hands-free flashcards for cooking. One big, glanceable card per step (plus an
//  ingredients card), navigated by waving a hand in front of the phone (front-camera
//  hand-pose) — or by swiping. The card stays full-screen; only a small status pill
//  shows whether hands-free tracking is live. Honors Reduce Motion.
//

import SwiftUI

struct FlashcardCookScreen: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var gesture = HandGestureController()
    @StateObject private var voice = VoiceCommandController()

    @State private var index = 0
    @State private var handsFree = true
    @State private var voiceOn = true

    private let cards: [FlashCard]
    private let stepCount: Int

    init(recipe: Recipe) {
        self.recipe = recipe
        var list: [FlashCard] = []
        let ingredients = recipe.ingredients.flatMap(\.items)
        if !ingredients.isEmpty { list.append(.ingredients(ingredients)) }
        let steps = recipe.directions.sorted { $0.stepIndex < $1.stepIndex }
        for (i, s) in steps.enumerated() { list.append(.step(number: i + 1, text: s.text)) }
        self.cards = list.isEmpty ? [.step(number: 1, text: "No steps for this recipe yet.")] : list
        self.stepCount = steps.count
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(cards.indices, id: \.self) { i in
                    CardContent(card: cards[i], stepCount: stepCount)
                        .padding(.horizontal, AppSpacing.lg)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                topBar
                if voice.permissionDenied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Speech / Mic Disabled · Tap to Enable in Settings")
                                .font(AppFont.body(13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    }
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
                if voiceOn && voice.wakeActive {
                    FloatingVoiceAssistantView(voice: voice)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.6).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            )
                        )
                        .padding(.bottom, 16)
                }
                bottomBar
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: voice.wakeActive)
            .animation(.easeInOut(duration: 0.25), value: voice.permissionDenied)
        }
        .onAppear {
            gesture.onGesture = { dir in advance(dir) }
            voice.onCommand = { cmd in advance(cmd == .next ? .next : .previous) }
            if handsFree { gesture.start() }
            if voiceOn { voice.start() }
        }
        .onDisappear { gesture.stop(); voice.stop() }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                Haptics.tap(); dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.surface, in: Circle())
                    .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())

            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                handsFreePill
                voicePill
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }

    private var voicePill: some View {
        Button {
            if voice.permissionDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                return
            }
            voiceOn.toggle()
            Haptics.tap()
            if voiceOn { voice.start() } else { voice.stop() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: voiceOn ? (voice.wakeActive ? "waveform.badge.mic" : "mic.fill") : "mic.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(voiceStatusText)
                    .font(AppFont.body(13, weight: .semibold))
                if voiceOn && voice.isListening {
                    Circle()
                        .fill(voice.wakeActive ? AppTheme.accent : AppTheme.accentSoft)
                        .frame(width: 8, height: 8)
                        .scaleEffect(voice.wakeActive ? 1.3 : 1.0)
                }
            }
            .foregroundStyle(voiceOn ? (voice.wakeActive ? AppTheme.accent : AppTheme.accentInk) : AppTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(voice.wakeActive ? AppTheme.accentSoft : AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(voice.wakeActive ? AppTheme.accent : AppTheme.hairline, lineWidth: voice.wakeActive ? 1.5 : 1))
            .shadow(color: voice.wakeActive ? AppTheme.accent.opacity(0.3) : Color.clear, radius: 8, y: 2)
            .animation(AppMotion.smooth, value: voice.wakeActive)
        }
        .buttonStyle(PressableStyle())
    }

    private var voiceStatusText: String {
        if !voiceOn { return "Voice off" }
        if voice.permissionDenied { return "Enable mic & speech" }
        if voice.isListening {
            return "Listening… say “Next”"
        }
        return "Starting…"
    }

    private var handsFreePill: some View {
        Button {
            handsFree.toggle()
            Haptics.tap()
            if handsFree { gesture.start() } else { gesture.stop() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: handsFree ? "hand.raised.fill" : "hand.raised.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(statusText)
                    .font(AppFont.body(13, weight: .semibold))
                if handsFree && gesture.isRunning {
                    Circle()
                        .fill(gesture.handDetected ? AppTheme.accent : AppTheme.textTertiary)
                        .frame(width: 8, height: 8)
                }
            }
            .foregroundStyle(handsFree ? AppTheme.accentInk : AppTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var statusText: String {
        if !handsFree { return "Hands-free off" }
        if gesture.permissionDenied { return "Enable camera" }
        if !gesture.cameraAvailable { return "Swipe to move" }
        if gesture.isRunning { return gesture.handDetected ? "Hand detected" : "Wave to flip" }
        return "Starting…"
    }

    // MARK: Bottom bar (progress + hint)

    private var bottomBar: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 6) {
                ForEach(cards.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? AppTheme.accent : AppTheme.separator)
                        .frame(width: i == index ? 22 : 7, height: 7)
                        .animation(reduceMotion ? nil : AppMotion.snappy, value: index)
                }
            }
            Text(hint)
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.bottom, AppSpacing.lg)
    }

    private var hint: String {
        if voiceOn && voice.isListening { return "Say “next” or “back” — or wave your hand" }
        if handsFree && gesture.isRunning { return "Wave your hand left or right — no need to touch" }
        return "Swipe left or right to move through the recipe"
    }

    // MARK: Navigation

    private func advance(_ dir: HandGestureController.Direction) {
        let next = dir == .next ? index + 1 : index - 1
        guard next >= 0, next < cards.count, next != index else { return }
        withAnimation(reduceMotion ? nil : AppMotion.smooth) { index = next }
        Haptics.select()
    }
}

// MARK: - Card model + content

enum FlashCard {
    case ingredients([String])
    case step(number: Int, text: String)
}

private struct CardContent: View {
    let card: FlashCard
    let stepCount: Int

    var body: some View {
        switch card {
        case .ingredients(let items):
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Prep").sectionLabelStyle(AppTheme.accentInk)
                Text("Ingredients")
                    .font(AppFont.display(34, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                Circle().fill(AppTheme.accent).frame(width: 7, height: 7).padding(.top, 9)
                                Text(item)
                                    .font(AppFont.body(19))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.vertical, 90)

        case .step(let number, let text):
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Step \(number) of \(stepCount)").sectionLabelStyle(AppTheme.accentInk)
                Text(text)
                    .font(AppFont.display(30, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.vertical, 90)
        }
    }
}

#Preview {
    FlashcardCookScreen(recipe: Recipe.placeholderRecipes[0])
}
