//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: SpeechReader.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Audio text-to-speech engine reading recipe steps aloud during Cook Mode.
//
// 2. ARCHITECTURAL ROLE:
//    Controls AVSpeechSynthesizer with natural speech pauses, rate adjustments, and language adaptation.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "SpeechReader acts as an audio sous-chef. It uses AVSpeechSynthesizer to speak cooking directions aloud step-by-step so the cook doesn't need to look at the screen."
//
// ==============================================================================
//

//
//  SpeechReader.swift
//  CraveCircle (AICookBook)
//
//  Reads a flashcard aloud with the device's best system voice (AVSpeechSynthesizer), at a calm,
//  easy-to-follow pace. Used by the hands-free cook screen: when "Read aloud" is on, each card is
//  spoken as it appears. It calls onStart/onFinish so the command mic can be muted WHILE speaking —
//  that way the TTS never echoes back into the recognizer or self-triggers "next".
//

import AVFoundation

/// Main-actor isolated: the synthesizer and the onStart/onFinish callbacks are only touched on the
/// main thread; the slow audio-session setup is pushed off-main explicitly with `@concurrent`.
@MainActor
final class SpeechReader: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()

    /// Called on the main thread when speech starts / ends — wire these to mute & unmute the mic.
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, language: String = "en-US") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: trimmed)
        u.voice = Self.bestVoice(language)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        u.preUtteranceDelay = 0.12
        u.postUtteranceDelay = 0.2
        // Session activate is the same main-thread hang as the search mic. Do it off-main,
        // then speak (back on the main actor after the await).
        Task { [weak self] in
            await Self.activateAudioSession()
            self?.synth.speak(u)
        }
    }

    /// `@concurrent` = always runs on the background thread pool, never on the main actor, so these
    /// blocking XPC calls can't freeze the UI. .default, not .voiceChat — voice-chat is a phone-call filter.
    @concurrent
    private nonisolated static func activateAudioSession() async {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default,
                                 options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        if #available(iOS 27, *) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                session.activate(options: []) { _, _ in cont.resume() }
            }
        } else {
            try? session.setActive(true)
        }
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    /// Prefer a Siri or premium voice. Eloquence is the old robotic voice and always loses.
    nonisolated static func voiceScore(identifier: String, quality: AVSpeechSynthesisVoiceQuality) -> Int {
        let id = identifier.lowercased()
        if id.contains("eloquence") { return 0 }
        var score: Int
        switch quality {
        case .premium: score = 5
        case .enhanced: score = 3
        default: score = 1
        }
        if id.contains("siri") { score += 20 }
        if id.contains("premium") { score += 4 }
        return score
    }

    private static func bestVoice(_ language: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(language.prefix(2))
        let best = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .max { voiceScore(identifier: $0.identifier, quality: $0.quality) < voiceScore(identifier: $1.identifier, quality: $1.quality) }
        return best ?? AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: AVSpeechSynthesizerDelegate — mute the command mic around speech.

    // The synthesizer calls these on its own thread, so they're `nonisolated` and hop to the main actor.
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.onStart?() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.onFinish?() }
    }
    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.onFinish?() }
    }
}
