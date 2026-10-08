//
//  FlashcardCookScreen.swift
//  CraveCircle (AICookBook)
//
//  Hands-free, LANDSCAPE flashcards for cooking. One big, glanceable card per step on a bold
//  color (the colour changes every card), with the previous/next step faint above and below.
//  Navigate by voice ("next" / "back") or by swiping. If a step mentions a time ("cook for
//  15 minutes") a clock appears — say "start timer" (or tap it) to count down; it beeps when done.
//  Forces landscape while open, honours Reduce Motion.
//

import SwiftUI
import UIKit
import AudioToolbox
import Combine

struct FlashcardCookScreen: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var voice = VoiceCommandController()
    @StateObject private var timer = CookTimer()

    @State private var index = 0
    @State private var voiceOn = true
    @State private var readAloud = false
    @State private var reader = SpeechReader()

    private let cards: [FlashCard]
    private let stepCount: Int

    // Bold, cycling card colours (bg + a legible ink per card).
    static let palette: [(bg: Color, ink: Color)] = [
        (Color(hex: "C75146"), .white),            // terracotta red
        (Color(hex: "E0A13A"), Color(hex: "3A2A10")), // mustard amber
        (Color(hex: "B86AB8"), Color(hex: "2E1430")), // orchid purple
        (Color(hex: "4FA38B"), Color(hex: "0E2E26")), // teal
        (Color(hex: "5B7DB1"), .white),            // dusty blue
        (Color(hex: "D98299"), Color(hex: "3A1A24")), // rose
    ]
    private func color(for i: Int) -> (bg: Color, ink: Color) {
        Self.palette[((i % Self.palette.count) + Self.palette.count) % Self.palette.count]
    }

    init(recipe: Recipe) {
        self.recipe = recipe
        var list: [FlashCard] = []
        let ingredients = recipe.ingredients.flatMap(\.items)
        if !ingredients.isEmpty { list.append(.ingredients(ingredients)) }
        let steps = recipe.directions.sorted { $0.stepIndex < $1.stepIndex }
        for s in steps {
            for chunk in Self.chunkStep(s.text) {
                list.append(.step(number: list.filter(\.isStep).count + 1, text: chunk))
            }
        }
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
        let parts = clean.split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let separators: [String] = parts.count > 1 ? parts : clean.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard separators.count > 1 else { return [clean] }
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

    // Minutes mentioned in the current step, if any (drives the clock).
    private var currentDuration: Int? { cards.indices.contains(index) ? cards[index].durationMinutes : nil }

    private var scrollBinding: Binding<Int?> {
        Binding(get: { index }, set: { if let v = $0 { index = v } })
    }

    var body: some View {
        ZStack {
            color(for: index).bg.ignoresSafeArea()

            // Vertical paging: swipe UP for the next step, DOWN for the previous — like scrolling a
            // feed. Each card fills the screen and carries its own colour so the swap reads clearly.
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(cards.indices, id: \.self) { i in
                            CardContent(card: cards[i],
                                        stepCount: stepCount,
                                        ink: color(for: i).ink,
                                        prev: contextText(at: i - 1),
                                        next: contextText(at: i + 1))
                                .padding(.horizontal, 48)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .background(color(for: i).bg)
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                // Continuous vertical scroll (a feed), NOT slide-style paging — the colored cards
                // flow into each other as you scroll down. scrollPosition still tracks the top card.
                .scrollPosition(id: scrollBinding, anchor: .top)
            }
            .ignoresSafeArea()

            // Clock lives in the parent so a running timer persists while you swipe steps.
            if timer.running || currentDuration != nil {
                ClockRingView(timer: timer,
                              idleMinutes: currentDuration ?? 0,
                              tint: color(for: index).ink) {
                    toggleTimer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 36)
                .padding(.bottom, 30)
                .transition(.scale.combined(with: .opacity))
            }

            VStack {
                topBar
                if voice.permissionDenied { permissionBanner }
                Spacer()
                if voiceOn && voice.wakeActive {
                    FloatingVoiceAssistantView(voice: voice)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .padding(.bottom, 10)
                }
                bottomBar
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: voice.wakeActive)
            .animation(.easeInOut(duration: 0.25), value: voice.permissionDenied)
            .animation(reduceMotion ? nil : AppMotion.snappy, value: timer.running)
        }
        .foregroundStyle(color(for: index).ink)
        .onAppear {
            lockOrientation(.landscape)
            voice.onCommand = { cmd in handle(cmd) }
            reader.onStart = { [weak voice] in voice?.suppress(true) }
            reader.onFinish = { [weak voice] in voice?.suppress(false) }
            if voiceOn { voice.start() }
        }
        .onDisappear {
            lockOrientation(.portrait)
            voice.stop(); reader.stop(); timer.stop()
        }
        .onChange(of: index) { _, _ in speakCurrentCard() }
        .statusBarHidden(true)
    }

    // MARK: Commands

    private func handle(_ cmd: VoiceCommandController.Command) {
        switch cmd {
        case .next:       move(by: 1)
        case .previous:   move(by: -1)
        case .startTimer: toggleTimer()
        }
    }

    private func move(by delta: Int) {
        let next = index + delta
        guard next >= 0, next < cards.count else { return }
        withAnimation(reduceMotion ? nil : AppMotion.smooth) { index = next }
        Haptics.select()
    }

    private func toggleTimer() {
        guard let minutes = currentDuration, minutes > 0 else {
            if !timer.running { Haptics.warning() }   // nothing to time on this step
            else { timer.stop(); Haptics.tap() }
            return
        }
        Haptics.tap()
        timer.toggle(minutes: minutes)
    }

    /// Short context line for the card above/below (what the cook just did / will do next).
    private func contextText(at i: Int) -> String? {
        guard cards.indices.contains(i) else { return nil }
        switch cards[i] {
        case .ingredients:            return "Ingredients"
        case .step(let n, let t):     return "Step \(n): \(t)"
        case .finish:                 return "Finish 🎉"
        }
    }

    // MARK: Orientation

    /// Pin the app to `mask` and ask the active scene to rotate to it. The app is portrait
    /// everywhere else (see `AppDelegate.orientationLock`).
    private func lockOrientation(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    private func speakCurrentCard() {
        guard readAloud, cards.indices.contains(index) else { return }
        reader.speak(flashcardSpokenText(cards[index]))
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 10) {
            iconButton("xmark", label: "Exit Flashcards") { Haptics.tap(); dismiss() }
            Spacer()
            iconButton(readAloud ? "speaker.wave.2.fill" : "speaker.slash.fill",
                       label: readAloud ? "Turn off read aloud" : "Read steps aloud") {
                Haptics.tap(); readAloud.toggle()
                if readAloud { speakCurrentCard() } else { reader.stop() }
            }
            voicePill
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private func iconButton(_ system: String, label: String, action: @escaping () -> Void) -> some View {
        let ink = color(for: index).ink
        return Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 38, height: 38)
                .background(ink.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(ink.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private var voicePill: some View {
        let ink = color(for: index).ink
        return Button {
            if voice.permissionDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                return
            }
            voiceOn.toggle(); Haptics.tap()
            if voiceOn { voice.start() } else { voice.stop() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: voiceOn ? (voice.wakeActive ? "waveform.badge.mic" : "mic.fill") : "mic.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(voiceStatusText).font(AppFont.body(13, weight: .semibold))
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(ink.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(ink.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var voiceStatusText: String {
        if !voiceOn { return "Voice off" }
        if voice.permissionDenied { return "Enable mic & speech" }
        if voice.isListening { return "Say “Next” · “Start timer”" }
        return "Starting…"
    }

    private var permissionBanner: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        } label: {
            Text("Speech / Mic Disabled · Tap to Enable in Settings")
                .font(AppFont.body(13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color.red, in: Capsule())
        }
        .padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var bottomBar: some View {
        let ink = color(for: index).ink
        return HStack(spacing: 6) {
            ForEach(cards.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? ink : ink.opacity(0.3))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(reduceMotion ? nil : AppMotion.snappy, value: index)
            }
        }
        .padding(.bottom, 18)
    }
}

// MARK: - Cook timer

/// A simple minute countdown with an animated progress value and a beep on completion.
final class CookTimer: ObservableObject {
    @Published private(set) var remaining = 0   // seconds left
    @Published private(set) var total = 0
    @Published private(set) var running = false

    private var ticker: Timer?

    var progress: Double { total > 0 ? Double(remaining) / Double(total) : 0 }
    var clockText: String { String(format: "%d:%02d", remaining / 60, remaining % 60) }

    func toggle(minutes: Int) { running ? stop() : start(minutes: minutes) }

    func start(minutes: Int) {
        stop()
        total = max(minutes, 0) * 60
        remaining = total
        guard total > 0 else { return }
        running = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remaining <= 1 { self.finish() } else { self.remaining -= 1 }
        }
    }

    func stop() {
        ticker?.invalidate(); ticker = nil
        running = false
    }

    private func finish() {
        remaining = 0
        stop()
        Self.playAlarm()
    }

    /// Three system beeps + a success haptic — a clear "time's up" without bundling an audio file.
    /// ponytail: uses the built-in alert sound; a custom chime is a later nicety.
    static func playAlarm() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        for delay in [0.0, 0.7, 1.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AudioServicesPlayAlertSound(SystemSoundID(1005))
            }
        }
    }
}

/// The white clock on a card. Idle: a timer glyph + the step's minutes. Running: the live countdown
/// with the ring draining. Tap to start/stop.
private struct ClockRingView: View {
    @ObservedObject var timer: CookTimer
    var idleMinutes: Int
    var tint: Color
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle().fill(.white)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                Circle().stroke(tint.opacity(0.18), lineWidth: 5)
                    .padding(6)
                Circle()
                    .trim(from: 0, to: timer.running ? timer.progress : 1)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                    .animation(.linear(duration: 0.9), value: timer.progress)
                VStack(spacing: 1) {
                    if timer.running {
                        Text(timer.clockText)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    } else {
                        Image(systemName: "timer").font(.system(size: 17, weight: .bold)).foregroundStyle(tint)
                        Text("\(idleMinutes) min")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                    }
                }
            }
            .frame(width: 92, height: 92)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(timer.running ? "Stop timer" : "Start \(idleMinutes) minute timer")
    }
}

// MARK: - Card model + content

enum FlashCard {
    case ingredients([String])
    case step(number: Int, text: String)
    case finish(recipeTitle: String)

    var isStep: Bool { if case .step = self { return true } else { return false } }
    var isFinish: Bool { if case .finish = self { return true } else { return false } }

    /// Minutes mentioned in a step's text ("cook for 15 minutes" → 15), else nil.
    var durationMinutes: Int? {
        guard case .step(_, let text) = self else { return nil }
        return stepDurationMinutes(text)
    }
}

/// Parse an explicit cooking time out of step prose. Requires minute/hour WORDS so plain numbers
/// (oven temps, counts) don't false-trigger. Sums hours + minutes.
func stepDurationMinutes(_ text: String) -> Int? {
    let t = text.lowercased()
    func firstInt(_ pattern: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let r = Range(m.range(at: 1), in: t) else { return nil }
        return Int(t[r])
    }
    let h = firstInt("(\\d+)\\s*(?:hours?|hrs?|hr)\\b")
    let m = firstInt("(\\d+)\\s*(?:minutes?|mins?|min)\\b")
    guard h != nil || m != nil else { return nil }
    return (h ?? 0) * 60 + (m ?? 0)
}

private struct CardContent: View {
    let card: FlashCard
    let stepCount: Int
    let ink: Color
    let prev: String?
    let next: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Previous step, faint
            Text(prev ?? " ")
                .font(AppFont.body(15, weight: .semibold))
                .foregroundStyle(ink.opacity(0.45))
                .lineLimit(2)

            Spacer(minLength: 4)
            center
            Spacer(minLength: 4)

            // Next step, faint
            Text(next ?? " ")
                .font(AppFont.body(15, weight: .semibold))
                .foregroundStyle(ink.opacity(0.45))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.vertical, 54)
    }

    @ViewBuilder private var center: some View {
        switch card {
        case .ingredients(let items):
            VStack(alignment: .leading, spacing: 10) {
                Text("INGREDIENTS")
                    .font(AppFont.label(13, weight: .bold)).tracking(1.5)
                    .foregroundStyle(ink.opacity(0.7))
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 10) {
                                Circle().fill(ink.opacity(0.6)).frame(width: 6, height: 6).padding(.top, 9)
                                Text(item).font(AppFont.body(18, weight: .medium)).foregroundStyle(ink)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

        case .step(let number, let text):
            VStack(alignment: .leading, spacing: 10) {
                Text(number == stepCount ? "LAST STEP · \(number)/\(stepCount)" : "STEP \(number) OF \(stepCount)")
                    .font(AppFont.label(13, weight: .bold)).tracking(1.5)
                    .foregroundStyle(ink.opacity(0.7))
                Text(text)
                    .font(AppFont.display(34, weight: .bold))
                    .foregroundStyle(ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
            }

        case .finish(let recipeTitle):
            VStack(alignment: .leading, spacing: 8) {
                Text("🎉").font(.system(size: 44))
                Text("Enjoy your meal!")
                    .font(AppFont.display(34, weight: .bold)).foregroundStyle(ink)
                Text("You finished \(recipeTitle). Bon appétit, chef!")
                    .font(AppFont.body(17, weight: .medium)).foregroundStyle(ink.opacity(0.8))
            }
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
