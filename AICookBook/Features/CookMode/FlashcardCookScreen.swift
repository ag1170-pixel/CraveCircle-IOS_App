//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: FlashcardCookScreen.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Full-screen hands-free cooking mode displaying atomic step-by-step instructions.
//
// 2. ARCHITECTURAL ROLE:
//    High-contrast cooking UI: displays large direction cards, self-starting timers, step progress dots, and voice assistant integration.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "FlashcardCookScreen is built for the kitchen counter. It presents full-screen high-contrast cards with large typography so it's readable from a distance. It incorporates self-starting timers and responds to voice commands so users never touch the screen with dirty fingers."
//
// ==============================================================================
//

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

// MARK: - SwiftUI View Component
struct FlashcardCookScreen: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var voice = VoiceCommandController()
    @State private var timer = CookTimer()

    @State private var index = 0
    @State private var timerStepNumber: Int?
    @State private var voiceOn = true
    @State private var readAloud = false
    @State private var reader = SpeechReader()

    private let cards: [FlashCard]
    private let stepCount: Int

    // Dark cook theme: near-black at the top, a muted warm glow at the bottom. The glow
    // shifts per step (brown, olive, cocoa) so cards still change, and the ink stays white.
    static let palette: [(glow: Color, ink: Color)] = [
        (Color(hex: "6A4032"), .white),
        (Color(hex: "3E4C30"), .white),
        (Color(hex: "5C382C"), .white),
        (Color(hex: "3A4034"), .white),
        (Color(hex: "4E3428"), .white),
        (Color(hex: "2E3A32"), .white),
    ]
    private func color(for i: Int) -> (glow: Color, ink: Color) {
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
    private var currentStepNumber: Int? {
        guard cards.indices.contains(index), case .step(let number, _) = cards[index] else { return nil }
        return number
    }

    private var scrollBinding: Binding<Int?> {
        Binding(get: { index }, set: { if let v = $0 { index = v } })
    }

    var body: some View {
        ZStack {
            // Whole-screen background. Near-black on top, the step's warm glow along the bottom.
            ZStack {
                Color(hex: "12100E")
                LinearGradient(
                    colors: [Color(hex: "12100E"), color(for: index).glow],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
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

            if timer.running || timer.completed || currentDuration != nil {
                HStack(spacing: 10) {
                    ClockRingView(
                        timer: timer,
                        idleMinutes: timer.running || timer.completed ? timer.total / 60 : currentDuration ?? 0,
                        stepNumber: timer.running || timer.completed ? timerStepNumber : currentStepNumber,
                        diameter: 108,
                        tint: Color(hex: "F2B89B")
                    ) {
                        toggleTimer()
                    }

                    if timer.completed {
                        Button {
                            dismissCompletedTimer()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "F2B89B"))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(PressableStyle())
                        .modifier(FlashcardTimerGlassSurface(
                            reduceTransparency: reduceTransparency,
                            tint: Color(hex: "F2B89B")
                        ))
                        .accessibilityLabel("Dismiss completed timer for step \(timerStepNumber ?? 0)")
                        .accessibilityValue("Completed")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, max(14, Self.displayEdgeInsets.left + 10))
                .padding(.bottom, max(14, Self.displayEdgeInsets.bottom + 8))
                .transition(.scale.combined(with: .opacity))
            }

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
            .overlay(alignment: .trailing) {
                stepRail
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.top, 78)
                    .padding(.bottom, (timer.running || currentDuration != nil) ? 140 : 28)
                    .padding(.trailing, max(18, Self.displayEdgeInsets.right + 10))
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: voice.wakeActive)
            .animation(.easeInOut(duration: 0.25), value: voice.permissionDenied)
            .animation(reduceMotion ? nil : AppMotion.snappy, value: timer.running)
        }
        .foregroundStyle(color(for: index).ink)
        .onAppear {
            lockOrientation(.landscape)
            voice.onCommand = { cmd in handle(cmd) }
            let voice = voice   // capture the controller object weakly, not the view
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
        timerStepNumber = currentStepNumber
        timer.start(minutes: minutes)
    }

    private func toggleTimer() {
        if timer.completed {
            let minutes = timer.total / 60
            guard minutes > 0 else { return }
            Haptics.tap()
            timer.start(minutes: minutes)
            return
        }
        if timer.running {
            timer.stop()
            timerStepNumber = nil
            Haptics.tap()
            return
        }
        guard let minutes = currentDuration, minutes > 0 else {
            Haptics.warning()   // nothing to time on this step
            return
        }
        Haptics.tap()
        timerStepNumber = currentStepNumber
        timer.start(minutes: minutes)
    }

    private func dismissCompletedTimer() {
        guard timer.completed else { return }
        timer.stop()
        timerStepNumber = nil
        Haptics.tap()
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
            iconButton(readAloud ? "speaker.wave.2.fill" : "speaker.slash.fill",
                       size: 50,
                       label: readAloud ? "Turn off read aloud" : "Read steps aloud") {
                Haptics.tap(); readAloud.toggle()
                if readAloud { speakCurrentCard() } else { reader.stop() }
            }
            voiceButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private func iconButton(_ system: String, size: CGFloat = 38, label: String, action: @escaping () -> Void) -> some View {
        let ink = color(for: index).ink
        return Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size > 40 ? 18 : 14, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: size, height: size)
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
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 50, height: 50)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(index + 1) of \(cards.count)")
    }
}

// MARK: - Cook timer

/// A simple minute countdown with an animated progress value and a beep on completion.
@Observable
final class CookTimer {
    private(set) var remaining = 0   // seconds left
    private(set) var total = 0
    private(set) var running = false
    private(set) var completed = false

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
        completed = false
    }

    private func finish() {
        remaining = 0
        ticker?.invalidate(); ticker = nil
        running = false
        completed = true
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

/// Stable identity for a split line in a recipe direction. `stepIndex` identifies the source
/// direction and `lineIndex` identifies the displayed line produced from that direction.
struct RecipeDirectionLineID: Hashable {
    let recipeID: String
    let stepIndex: Int
    let lineIndex: Int
}

/// A display-ready direction line. The detail screen uses this same flattened representation for
/// its checklist and timer actions so a timer stays attached to the instruction that started it.
struct RecipeDirectionLine: Identifiable, Hashable {
    let id: RecipeDirectionLineID
    let stepNumber: Int
    let text: String
    let durationSeconds: Int?

    var durationMinutes: Int? {
        guard let durationSeconds else { return nil }
        return max(1, durationSeconds / 60 + (durationSeconds % 60 == 0 ? 0 : 1))
    }
}

/// Flatten directions using the same line splitting as the recipe detail UI and annotate explicit
/// cooking durations. Stable IDs are independent of the flattened display number.
func recipeDirectionLines(recipeID: String, directions: [DirectionStep]) -> [RecipeDirectionLine] {
    var result: [RecipeDirectionLine] = []
    for direction in directions.sorted(by: { $0.stepIndex < $1.stepIndex }) {
        for (lineIndex, text) in DirectionStepParser.shortLines(direction.text).enumerated() {
            result.append(RecipeDirectionLine(
                id: RecipeDirectionLineID(recipeID: recipeID,
                                          stepIndex: direction.stepIndex,
                                          lineIndex: lineIndex),
                stepNumber: result.count + 1,
                text: text,
                durationSeconds: stepDurationSeconds(text)
            ))
        }
    }
    return result
}

enum RecipeDirectionTimerStatus: String, Hashable {
    case running
    case paused
    case completed
}

/// One recipe-direction timer. An absent entry represents the idle state; completed entries remain
/// in the store until dismissed so the UI can expose completion and restart actions.
struct RecipeDirectionTimerEntry: Identifiable, Hashable {
    let id: RecipeDirectionLineID
    let stepNumber: Int
    let instruction: String
    let durationSeconds: Int
    var remainingSeconds: Int
    var status: RecipeDirectionTimerStatus
    var deadline: Date?

    var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return 1 - Double(remainingSeconds) / Double(durationSeconds)
    }

    var clockText: String {
        if remainingSeconds >= 3_600 {
            return String(format: "%d:%02d:%02d", remainingSeconds / 3_600,
                          (remainingSeconds / 60) % 60, remainingSeconds % 60)
        }
        return String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }
}

/// Holds independent timers for the recipe Directions screen. Deadlines, rather than accumulated
/// ticks, keep countdowns accurate after view updates and refresh them when the app becomes active.
@MainActor
@Observable
final class RecipeDirectionTimerStore {
    private(set) var entries: [RecipeDirectionLineID: RecipeDirectionTimerEntry] = [:]

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var activeObserver: NSObjectProtocol?

    init() {
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    deinit {
        ticker?.invalidate()
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
    }

    var orderedEntries: [RecipeDirectionTimerEntry] {
        entries.values.sorted {
            if $0.status == .completed && $1.status != .completed { return false }
            if $1.status == .completed && $0.status != .completed { return true }
            return $0.stepNumber < $1.stepNumber
        }
    }

    /// Starts a new timer or deliberately restarts a completed timer. Existing running or paused
    /// timers are left untouched, so starting another direction never replaces one silently.
    @discardableResult
    func start(for line: RecipeDirectionLine) -> Bool {
        guard let durationSeconds = line.durationSeconds, durationSeconds > 0 else { return false }
        if let current = entries[line.id], current.status != .completed { return false }

        entries[line.id] = RecipeDirectionTimerEntry(
            id: line.id,
            stepNumber: line.stepNumber,
            instruction: line.text,
            durationSeconds: durationSeconds,
            remainingSeconds: durationSeconds,
            status: .running,
            deadline: Date().addingTimeInterval(TimeInterval(durationSeconds))
        )
        Haptics.tap()
        refresh()
        return true
    }

    func pause(_ id: RecipeDirectionLineID) {
        refresh()
        guard var entry = entries[id], entry.status == .running else { return }
        entry.remainingSeconds = remaining(until: entry.deadline)
        entry.deadline = nil
        entry.status = .paused
        entries[id] = entry
        refreshTicker()
    }

    func resume(_ id: RecipeDirectionLineID) {
        guard var entry = entries[id], entry.status == .paused else { return }
        entry.deadline = Date().addingTimeInterval(TimeInterval(entry.remainingSeconds))
        entry.status = .running
        entries[id] = entry
        refreshTicker()
    }

    /// Restarts a paused or completed timer at its original duration.
    func restart(_ id: RecipeDirectionLineID) {
        guard var entry = entries[id], entry.status != .running else { return }
        entry.remainingSeconds = entry.durationSeconds
        entry.deadline = Date().addingTimeInterval(TimeInterval(entry.durationSeconds))
        entry.status = .running
        entries[id] = entry
        Haptics.tap()
        refreshTicker()
    }

    /// Stops and removes a running or paused timer. Completed entries use `dismissCompleted`.
    func stop(_ id: RecipeDirectionLineID) {
        guard let existing = entries[id], existing.status != .completed else { return }
        entries[id] = nil
        Haptics.tap()
        refreshTicker()
    }

    func dismissCompleted(_ id: RecipeDirectionLineID) {
        guard entries[id]?.status == .completed else { return }
        entries[id] = nil
    }

    /// Recomputes every running timer from its deadline. The UI can also call this on foreground
    /// activation; the store observes `didBecomeActive` itself as a defensive refresh.
    func refresh() {
        let now = Date()
        var finishedAny = false
        for id in Array(entries.keys) {
            guard var entry = entries[id], entry.status == .running,
                  let deadline = entry.deadline else { continue }
            let seconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
            if seconds == 0 {
                entry.remainingSeconds = 0
                entry.deadline = nil
                entry.status = .completed
                finishedAny = true
            } else {
                entry.remainingSeconds = seconds
            }
            entries[id] = entry
        }
        if finishedAny { CookTimer.playAlarm() }
        refreshTicker()
    }

    private func remaining(until deadline: Date?) -> Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSinceNow)))
    }

    private func refreshTicker() {
        let hasRunning = entries.values.contains { $0.status == .running }
        guard hasRunning else {
            ticker?.invalidate()
            ticker = nil
            return
        }
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }
}

/// The white clock on a card. Idle: a timer glyph + the step's minutes. Running: the live countdown
/// with the ring draining. Tap to start/stop.
private struct ClockRingView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var contentScale: CGFloat = 1

    var timer: CookTimer
    var idleMinutes: Int
    var stepNumber: Int?
    var diameter: CGFloat = 92
    var tint: Color
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .overlay {
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color(hex: "6D4636").opacity(0.12), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                Circle().stroke(.white.opacity(0.16), lineWidth: 5)
                    .padding(6)
                Circle()
                    .trim(from: 0, to: timer.running ? timer.progress : 1)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
                    .shadow(color: tint.opacity(0.36), radius: 4, y: 0)
                    .animation(reduceMotion ? nil : .linear(duration: 0.9), value: timer.progress)
                VStack(spacing: 1) {
                    if let stepNumber {
                        Text("STEP \(stepNumber)")
                            .font(AppFont.label(11, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(tint.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if timer.completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(tint)
                        Text("DONE")
                            .font(AppFont.label(11, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(tint)
                    } else if timer.running {
                        Text(timer.clockText)
                            .font(AppFont.mono(19, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Image(systemName: "timer").font(.system(size: 17, weight: .bold)).foregroundStyle(tint)
                        Text("\(idleMinutes) min")
                            .font(AppFont.body(12, weight: .bold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(width: diameter * contentScale, height: diameter * contentScale)
        }
        .buttonStyle(PressableStyle())
        .modifier(FlashcardTimerGlassSurface(reduceTransparency: reduceTransparency, tint: tint))
        .accessibilityLabel(timer.completed
                            ? "Restart completed timer for step \(stepNumber ?? 0)"
                            : (timer.running
                               ? "Stop timer for step \(stepNumber ?? 0)"
                               : "Start \(idleMinutes) minute timer for step \(stepNumber ?? 0)"))
        .accessibilityValue(timer.completed
                            ? "Completed, \(timer.total / 60) minutes"
                            : (timer.running
                               ? "Running, \(timer.clockText) remaining"
                               : "Ready, \(idleMinutes) minutes"))
    }
}

private struct FlashcardTimerGlassSurface: ViewModifier {
    let reduceTransparency: Bool
    let tint: Color

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(Color(hex: "201A16"), in: Circle())
            } else {
                content.glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .overlay {
            Circle().stroke(
                LinearGradient(
                    colors: [Color.white.opacity(reduceTransparency ? 0.28 : 0.72), tint.opacity(0.45), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.7
            )
            .allowsHitTesting(false)
        }
        .overlay {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.8).padding(4)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
        .shadow(color: tint.opacity(0.12), radius: 7, y: 1)
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

/// Parse one explicit duration from a direction. Plain numbers (oven temperatures and quantities)
/// are ignored. A contiguous hour/minute/second amount such as "1 hour and 30 minutes" is treated
/// as one duration; ranges and distinct intervals in a single line are considered ambiguous.
func stepDurationSeconds(_ text: String) -> Int? {
    parseStepDurationSeconds(text, includeSeconds: true)
}

/// Flashcards historically expose minute precision, so keep their parser on minute/hour values.
func stepDurationMinutes(_ text: String) -> Int? {
    guard text.range(of: #"(?i)\b(?:seconds?|secs?|sec)\b"#, options: .regularExpression) == nil,
          let seconds = parseStepDurationSeconds(text, includeSeconds: false),
          seconds % 60 == 0 else { return nil }
    return seconds / 60
}

private func parseStepDurationSeconds(_ text: String, includeSeconds: Bool) -> Int? {
    let normalized = text.lowercased()
    let rangePattern = #"\b\d+\s*(?:[-–—]|\bto\b)\s*\d+\s*(?:hours?|hrs?|hr|minutes?|mins?|min|seconds?|secs?|sec)\b"#
    if normalized.range(of: rangePattern, options: .regularExpression) != nil { return nil }

    let unitPattern = includeSeconds
        ? #"(?<![\p{L}\p{N}.])(\d+)\s*(hours?|hrs?|hr|minutes?|mins?|min|seconds?|secs?|sec)\b"#
        : #"(?<![\p{L}\p{N}.])(\d+)\s*(hours?|hrs?|hr|minutes?|mins?|min)\b"#
    guard let regex = try? NSRegularExpression(pattern: unitPattern, options: [.caseInsensitive]) else { return nil }
    let searchRange = NSRange(normalized.startIndex..., in: normalized)
    let matches = regex.matches(in: normalized, range: searchRange)
    guard !matches.isEmpty, matches.count <= (includeSeconds ? 3 : 2) else { return nil }

    struct Part {
        let value: Int
        let unitOrder: Int
        let multiplier: Int
        let fullRange: Range<String.Index>
    }
    var parts: [Part] = []
    for match in matches {
        guard let valueRange = Range(match.range(at: 1), in: normalized),
              let unitRange = Range(match.range(at: 2), in: normalized),
              let fullRange = Range(match.range, in: normalized),
              let value = Int(normalized[valueRange]) else { return nil }
        let unit = String(normalized[unitRange])
        let part: Part
        if unit.hasPrefix("h") {
            part = Part(value: value, unitOrder: 0, multiplier: 3_600, fullRange: fullRange)
        } else if unit.hasPrefix("m") {
            part = Part(value: value, unitOrder: 1, multiplier: 60, fullRange: fullRange)
        } else {
            part = Part(value: value, unitOrder: 2, multiplier: 1, fullRange: fullRange)
        }
        parts.append(part)
    }

    if parts.count > 1 {
        for index in 1..<parts.count {
            let previous = parts[index - 1]
            let current = parts[index]
            guard current.unitOrder > previous.unitOrder else { return nil }
            let separator = String(normalized[previous.fullRange.upperBound..<current.fullRange.lowerBound])
            guard separator.range(of: #"^\s*(?:and\s*)?$"#, options: .regularExpression) != nil else { return nil }
        }
    }

    var total = 0
    for part in parts {
        let (seconds, multiplyOverflow) = part.value.multipliedReportingOverflow(by: part.multiplier)
        guard !multiplyOverflow else { return nil }
        let (sum, addOverflow) = total.addingReportingOverflow(seconds)
        guard !addOverflow else { return nil }
        total = sum
    }
    return total > 0 ? total : nil
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
