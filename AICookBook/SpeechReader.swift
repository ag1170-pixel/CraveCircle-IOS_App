//
//  SpeechReader.swift
//  CraveCircle (AICookBook)
//
//  Reads a flashcard's text aloud with the on-device system voice (AVSpeechSynthesizer). Used by the
//  hands-free cook screen: when "Read aloud" is on, each card is spoken as it appears, so a cook can
//  say "next" and hear the next step without looking. Coexists with the voice-command mic (the audio
//  session is playAndRecord with echo cancellation while listening).
//

import AVFoundation

final class SpeechReader {
    private let synth = AVSpeechSynthesizer()

    /// Speak `text`, cutting off anything currently being spoken. `language` is a BCP-47 code so a
    /// translated recipe can be read in its own language; falls back to the default voice.
    func speak(_ text: String, language: String = "en-US") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        // Make sure playback is allowed even when the listening session isn't active.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: trimmed)
        u.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.postUtteranceDelay = 0.1
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }
}
