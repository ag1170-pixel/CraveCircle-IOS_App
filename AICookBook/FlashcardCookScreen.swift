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
        let steps = recipe.directions.sorted { $0.stepIndex < $1.stepIndex }
        for s in steps {
            for chunk in DirectionStepParser.shortLines(s.text) {
                list.append(.step(number: list.filter(\.isStep).count + 1, text: chunk))
            }
        }
        if !list.isEmpty { list.append(.finish(recipeTitle: recipe.title)) }
        self.cards = list.isEmpty ? [.step(number: 1, text: "No steps for this recipe yet.")] : list
        self.stepCount = list.filter(\.isStep).count
    }

    // Minutes mentioned in the current step, if any (drives the clock).
    private var currentDuration: Int? { cards.indices.contains(index) ? cards[index].durationMinutes : nil }

    private var scrollBinding: Binding<Int?> {
        Binding(get: { index }, set: { if let v = $0 { index = v } })
    }

    var body: some View {
        ZStack {
            // Whole-screen background = the CENTERED step's colour; it animates as the wheel settles
            // on a new step.
            color(for: index).bg.ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: index)

            // A picker-WHEEL of steps (like the Clock alarm hour/minute wheel): one step per row, the
            // centred step big and the neighbours faint above/below. Scrolling moves one STEP at a
            // time with a smooth transition — not a whole 3-step page.
            GeometryReader { geo in
                let rowH = geo.size.height * 0.52
                // The wheel ignores the safe area and the status bar is hidden, so SwiftUI's
                // insets are 0 and the step line runs under the Dynamic Island. Read the window
                // and keep a floor that clears the island on whichever side the phone is rotated.
                let edges = Self.displayEdgeInsets
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(cards.indices, id: \.self) { i in
                            CardContent(card: cards[i], stepCount: stepCount, ink: color(for: index).ink)
                                .padding(.leading, max(88, edges.left + 24))
                                .padding(.trailing, max(88, edges.right + 28))
                                .frame(width: geo.size.width, height: rowH)
                                .scrollTransition(axis: .vertical) { content, phase in
                                    // Centre (identity) = full; neighbours fade & shrink → wheel feel.
                                    content
                                        .opacity(1 - min(abs(phase.value), 1) * 0.72)
                                        .scaleEffect(1 - min(abs(phase.value), 1) * 0.18)
                                }
                                .id(i)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: scrollBinding, anchor: .center)
                .contentMargins(.vertical, (geo.size.height - rowH) / 2, for: .scrollContent)
            }
            .ignoresSafeArea()

            VStack {
                topBar
                if voice.permissionDenied { permissionBanner }
                Spacer()
                if voiceOn && voice.wakeActive {
                    FloatingVoiceAssistantView(voice: voice, showsStartHint: currentDuration != nil)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .padding(.bottom, 18)
                }
            }
            .overlay(alignment: .trailing) { stepRail }
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
        case .startTimer: startTimer()
        }
    }

    private func move(by delta: Int) {
        let next = index + delta
        guard next >= 0, next < cards.count else { return }
        withAnimation(reduceMotion ? nil : AppMotion.smooth) { index = next }
        Haptics.select()
    }

    /// Voice "start" only begins a countdown, and only on a step that shows the clock.
    private func startTimer() {
        guard let minutes = currentDuration, minutes > 0, !timer.running else { return }
        Haptics.tap()
        timer.toggle(minutes: minutes)
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


    // MARK: Orientation

    /// Sensor-housing insets in the current orientation. Zero when no window is up yet.
    private static var displayEdgeInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }

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
            if timer.running || currentDuration != nil {
                ClockRingView(timer: timer,
                              idleMinutes: currentDuration ?? 0,
                              diameter: 58,
                              tint: Color(hex: "1B1712")) {
                    toggleTimer()
                }
                .transition(.scale.combined(with: .opacity))
            }
            iconButton(readAloud ? "speaker.wave.2.fill" : "speaker.slash.fill",
                       label: readAloud ? "Turn off read aloud" : "Read steps aloud") {
                Haptics.tap(); readAloud.toggle()
                if readAloud { speakCurrentCard() } else { reader.stop() }
            }
            voiceButton
        }
        .padding(.leading, max(20, Self.displayEdgeInsets.left + 12))
        .padding(.trailing, max(20, Self.displayEdgeInsets.right + 12))
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

    /// Mic only — the spoken commands live on the chef, not in this control.
    private var voiceButton: some View {
        let ink = color(for: index).ink
        let symbol = voice.permissionDenied ? "mic.slash.fill"
            : (voiceOn ? (voice.wakeActive ? "waveform.badge.mic" : "mic.fill") : "mic.slash.fill")
        return Button {
            if voice.permissionDenied {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                return
            }
            voiceOn.toggle(); Haptics.tap()
            if voiceOn { voice.start() } else { voice.stop() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 38, height: 38)
                .background(ink.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(ink.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(voiceOn ? "Turn off voice" : "Turn on voice")
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

    /// Step position, top → bottom on the right (landscape). Active card is the tall mark.
    private var stepRail: some View {
        let ink = color(for: index).ink
        return VStack(spacing: 6) {
            ForEach(cards.indices, id: \.self) { i in
                Capsule()
                    .fill(i == index ? ink : ink.opacity(0.3))
                    .frame(width: 7, height: i == index ? 22 : 7)
                    .animation(reduceMotion ? nil : AppMotion.snappy, value: index)
            }
        }
        .padding(.trailing, max(12, Self.displayEdgeInsets.right + 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(index + 1) of \(cards.count)")
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
            DispatchQueue.main.async {
                guard let self else { return }
                if self.remaining <= 1 { self.finish() } else { self.remaining -= 1 }
            }
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
    var diameter: CGFloat = 92
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
            .scaleEffect(diameter / 92)
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(timer.running ? "Stop timer" : "Start \(idleMinutes) minute timer")
    }
}

// MARK: - Card model + content

enum FlashCard {
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

/// One step = one wheel row. Renders just this step's content, centred vertically and left-aligned;
/// the wheel itself shows the neighbouring steps (faint) above and below.
private struct CardContent: View {
    let card: FlashCard
    let stepCount: Int
    let ink: Color

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch card {
        case .step(let number, let text):
            VStack(alignment: .leading, spacing: 10) {
                Text(number == stepCount ? "LAST STEP · \(number)/\(stepCount)" : "STEP \(number) OF \(stepCount)")
                    .font(AppFont.label(13, weight: .bold)).tracking(1.5)
                    .foregroundStyle(ink.opacity(0.7))
                Text(text)
                    .font(AppFont.display(30, weight: .bold))
                    .foregroundStyle(ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.6)
            }

        case .finish(let recipeTitle):
            VStack(alignment: .leading, spacing: 8) {
                Text("🎉").font(.system(size: 44))
                Text("Enjoy your meal!")
                    .font(AppFont.display(32, weight: .bold)).foregroundStyle(ink)
                Text("You finished \(recipeTitle). Bon appétit, chef!")
                    .font(AppFont.body(17, weight: .medium)).foregroundStyle(ink.opacity(0.8))
            }
        }
    }
}

/// The words read aloud for a card (the step itself, or a spoken finish line).
func flashcardSpokenText(_ card: FlashCard) -> String {
    switch card {
    case .step(_, let text):      return text
    case .finish(let title):      return "You finished \(title). Enjoy your meal, chef!"
    }
}

#Preview {
    FlashcardCookScreen(recipe: Recipe.placeholderRecipes[0])
}
