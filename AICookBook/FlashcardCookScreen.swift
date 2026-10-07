//
//  FlashcardCookScreen.swift
//  CraveCircle (AICookBook)
//
//  Hands-free flashcards for cooking. One big, glanceable card per step (plus an
//  ingredients card), navigated by voice ("next" / "back") — or by swiping. The card
//  stays full-screen; only a small status pill shows whether voice is live. Honors
//  Reduce Motion.
//

import SwiftUI

struct FlashcardCookScreen: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var voice = VoiceCommandController()

    @State private var index = 0
    @State private var voiceOn = true
    @State private var readAloud = false
    @State private var reader = SpeechReader()

    private let cards: [FlashCard]
    private let stepCount: Int

    init(recipe: Recipe) {
        self.recipe = recipe
        var list: [FlashCard] = []
        let ingredients = recipe.ingredients.flatMap(\.items)
        if !ingredients.isEmpty { list.append(.ingredients(ingredients)) }
        let steps = recipe.directions.sorted { $0.stepIndex < $1.stepIndex }
        // Long steps are split into glanceable sub-cards (~22 words each) so hands-free cooking
        // doesn't require the user to re-read a wall of text. Numbering stays sequential — easier
        // for the cook to follow — so a 3-sentence step 1 becomes cards 1, 2, 3.
        for s in steps {
            for chunk in Self.chunkStep(s.text) {
                list.append(.step(number: list.filter(\.isStep).count + 1, text: chunk))
            }
        }
        // A celebratory finish card closes the deck — the "you're done!" call.
        if !list.isEmpty { list.append(.finish(recipeTitle: recipe.title)) }
        self.cards = list.isEmpty ? [.step(number: 1, text: "No steps for this recipe yet.")] : list
        self.stepCount = list.filter(\.isStep).count
    }

    /// Split one direction into glanceable sub-cards. Prefers sentence boundaries; falls back to
    /// commas; leaves anything already short alone. Keeps up to `maxWords` per card.
    private static func chunkStep(_ text: String) -> [String] {
        let maxWords = 22
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        if clean.split(separator: " ").count <= maxWords { return [clean] }
        // Sentence-split (., !, ?). Merge short sentences so we don't produce 3-word cards.
        let parts = clean.split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let separators: [String] = parts.count > 1 ? parts : clean.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard separators.count > 1 else { return [clean] }     // can't split meaningfully
        var out: [String] = []
        var buf = ""
        for p in separators {
            let merged = buf.isEmpty ? p : "\(buf). \(p)"
            if merged.split(separator: " ").count <= maxWords { buf = merged }
            else { if !buf.isEmpty { out.append(buf) }; buf = p }
        }
        if !buf.isEmpty { out.append(buf) }
        return out
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
            voice.onCommand = { cmd in advance(cmd) }
            // Mute the command mic while a card is being read, so TTS can't echo or self-trigger.
            reader.onStart = { [weak voice] in voice?.suppress(true) }
            reader.onFinish = { [weak voice] in voice?.suppress(false) }
            if voiceOn { voice.start() }
        }
        .onDisappear { voice.stop(); reader.stop() }
        // Speak each card as it appears (voice "next"/"back" changes index → the new card is read).
        .onChange(of: index) { _, _ in speakCurrentCard() }
    }

    private func speakCurrentCard() {
        guard readAloud, cards.indices.contains(index) else { return }
        // ponytail: reads with the en-US system voice; multilingual TTS is a later upgrade.
        reader.speak(flashcardSpokenText(cards[index]))
    }

    private var readAloudButton: some View {
        Button {
            Haptics.tap()
            readAloud.toggle()
            if readAloud { speakCurrentCard() } else { reader.stop() }
        } label: {
            Image(systemName: readAloud ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(readAloud ? AppTheme.accentInk : AppTheme.textSecondary)
                .frame(width: 38, height: 38)
                .background(readAloud ? AppTheme.accentSoft : AppTheme.surface, in: Circle())
                .overlay(Circle().stroke(readAloud ? AppTheme.accent : AppTheme.hairline, lineWidth: readAloud ? 1.5 : 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(readAloud ? "Turn off read aloud" : "Read steps aloud")
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
            .accessibilityLabel("Exit Flashcards")

            Spacer()
            readAloudButton
            voicePill
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
        if voiceOn && voice.isListening { return "Say “next” or “back” — or swipe to move" }
        return "Swipe left or right to move through the recipe"
    }

    // MARK: Navigation

    private func advance(_ dir: VoiceCommandController.Command) {
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
    case finish(recipeTitle: String)

    var isStep: Bool { if case .step = self { return true } else { return false } }
    var isFinish: Bool { if case .finish = self { return true } else { return false } }
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
                HStack(spacing: 8) {
                    Text("Step \(number) of \(stepCount)").sectionLabelStyle(AppTheme.accentInk)
                    if number == stepCount {
                        Text("LAST STEP")
                            .font(AppFont.label(11, weight: .bold)).tracking(0.8)
                            .foregroundStyle(AppTheme.accentInk)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(AppTheme.accentSoft, in: Capsule())
                    }
                }
                Text(text)
                    .font(AppFont.display(30, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.vertical, 90)

        case .finish(let recipeTitle):
            VStack(spacing: AppSpacing.md) {
                Text("🎉")
                    .font(.system(size: 64))
                Text("Enjoy your meal!")
                    .font(AppFont.display(34, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("You finished \(recipeTitle). Bon appétit, chef!")
                    .font(AppFont.body(17))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 90)
        }
    }
}

/// The words read aloud for a card (steps verbatim; ingredients listed; a spoken finish line).
func flashcardSpokenText(_ card: FlashCard) -> String {
    switch card {
    case .ingredients(let items): return "Ingredients. " + items.joined(separator: ", ")
    case .step(_, let text):      return text
    case .finish(let title):      return "You finished \(title). Enjoy your meal, chef!"
    }
}

#Preview {
    FlashcardCookScreen(recipe: Recipe.placeholderRecipes[0])
}
