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
        if session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, mode: .voiceChat,
                                     options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP])
        }
        try? session.setActive(true)

        let u = AVSpeechUtterance(string: trimmed)
        u.voice = Self.bestVoice(language)
        u.rate = 0.44                       // a touch slower than default (0.5) so each step is easy to follow
        u.pitchMultiplier = 1.0
        u.preUtteranceDelay = 0.0
        u.postUtteranceDelay = 0.15
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    /// Highest-quality installed voice for the language: premium → enhanced → default. Siri's own
    /// voice isn't exposed to apps, so we pick the best AVSpeech voice present; a user who downloads
    /// an Enhanced/Premium English voice (Settings › Accessibility › Spoken Content › Voices) then
    /// gets a far more natural, less "computery" read automatically.
    private static func bestVoice(_ language: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(language.prefix(2))
        func rank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
            switch q {
            case .premium:  return 3
            case .enhanced: return 2
            default:        return 1
            }
        }
        let best = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .max { rank($0.quality) < rank($1.quality) }
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
