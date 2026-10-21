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
        // Record-capable category so TTS coexists with the command mic. NEVER plain .playback —
        // that deactivates the mic's .playAndRecord session and breaks "next"/"back".
        let session = AVAudioSession.sharedInstance()
        // .default, not .voiceChat. Voice-chat mode is a phone-call filter and is what made
        // every step sound like a robot, especially when the next card cut in.
        try? session.setCategory(.playAndRecord, mode: .default,
                                 options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setActive(true)

        let u = AVSpeechUtterance(string: trimmed)
        u.voice = Self.bestVoice(language)
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        u.preUtteranceDelay = 0.12
        u.postUtteranceDelay = 0.2
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    /// Prefer a Siri or premium voice. Eloquence is the old robotic voice and always loses.
    static func voiceScore(identifier: String, quality: AVSpeechSynthesisVoiceQuality) -> Int {
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

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onStart?() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish?() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.onFinish?() }
    }
}
