//
//  VoiceCommandController.swift
//  CraveCircle (AICookBook)
//
//  Hands-free flashcard navigation by VOICE. Listens on-device (SFSpeechRecognizer +
//  AVAudioEngine) with hardware acoustic noise cancellation and "Hey Siri"-style
//  keyword activation ("Hey Crave"). Once activated, stays active until the user
//  leaves the screen or toggles off.
//

import Foundation
import Speech
import AVFoundation
import QuartzCore
import Combine

final class VoiceCommandController: NSObject, ObservableObject {
    enum Command { case next, previous }

    @Published private(set) var isListening = false
    @Published private(set) var available = true
    @Published private(set) var permissionDenied = false
    @Published private(set) var wakeActive = true
    @Published private(set) var lastHeard = ""

    /// Fired on the main thread when a command word is heard.
    var onCommand: ((Command) -> Void)?

    private let recognizer: SFSpeechRecognizer? = {
        SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()
    }()

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastFireTime: CFTimeInterval = 0
    private var lastConsumedIndex: Int = 0
    private let cooldown: CFTimeInterval = 0.6

    /// While true, mic audio is NOT fed to the recognizer — set this during text-to-speech so the
    /// spoken step can't echo back or self-trigger "next". Toggled by SpeechReader's start/finish.
    private var suppressed = false
    func suppress(_ on: Bool) {
        guard suppressed != on else { return }
        suppressed = on
        if on {
            // Kill the recognition task so it can't time out from audio starvation during TTS.
            task?.cancel(); task = nil
            request?.endAudio(); request = nil
        } else {
            // TTS finished — spin a fresh recognition session. The engine tap is still running.
            lastFireTime = CACurrentMediaTime()   // cooldown so a tail word can't fire late
            if isListening { startRecognition() }
        }
    }

    // Words that trigger navigation (+ common mis-hears, since on-device recognition of a single
    // short word is imperfect).
    private let nextWords: Set<String> = [
        "next", "forward", "skip", "continue", "advance", "nex", "neck", "necks", "nest", "nixed"
    ]
    private let backWords: Set<String> = [
        "back", "previous", "prev", "last", "reverse", "return", "repeat", "beck", "pack", "bag", "black"
    ]

    // MARK: Lifecycle

    func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let status = SFSpeechRecognizer.authorizationStatus()
            print("[VoiceCommand] Speech authorizationStatus: \(status.rawValue)")
            switch status {
            case .notDetermined:
                SFSpeechRecognizer.requestAuthorization { auth in
                    DispatchQueue.main.async {
                        print("[VoiceCommand] requestAuthorization result: \(auth.rawValue)")
                        if auth == .authorized {
                            self.checkMicAndBegin()
                        } else {
                            self.permissionDenied = true
                            self.available = false
                        }
                    }
                }
            case .authorized:
                self.checkMicAndBegin()
            case .denied, .restricted:
                self.permissionDenied = true
                self.available = false
            @unknown default:
                self.available = false
            }
        }
    }

    private func checkMicAndBegin() {
        let perm = AVAudioApplication.shared.recordPermission
        print("[VoiceCommand] Mic recordPermission: \(perm.rawValue)")
        switch perm {
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    print("[VoiceCommand] Mic requestRecordPermission granted: \(granted)")
                    if granted {
                        self?.beginSession()
                    } else {
                        self?.permissionDenied = true
                        self?.available = false
                    }
                }
            }
        case .granted:
            beginSession()
        case .denied:
            publish {
                self.permissionDenied = true
                self.available = false
            }
        @unknown default:
            publish { self.available = false }
        }
    }

    func stop() {
        isListening = false
        lastHeard = ""
        teardownAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Session Setup with Noise Cancellation

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            publish {
                self.available = false
                self.lastHeard = "Speech unavailable"
            }
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            publish {
                self.available = false
                self.lastHeard = "Audio error"
            }
            return
        }
        guard startEngine() else { return }
        startRecognition()
    }

    /// Start the mic engine ONCE and keep it running for the whole session. The tap feeds whatever
    /// request is current, so we can swap recognition sessions (after a command, or when one
    /// finalizes) WITHOUT stopping the engine. Stopping+restarting the engine on every command was
    /// what made the mic go dead after the first "next".
    @discardableResult
    private func startEngine() -> Bool {
        let node = audioEngine.inputNode
        node.removeTap(onBus: 0)
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            publish { self.available = false; self.lastHeard = "Invalid audio format" }
            return false
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, !self.suppressed else { return }   // don't feed TTS audio to the recognizer
            self.request?.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() }
        catch {
            publish { self.available = false; self.lastHeard = "Engine start error" }
            return false
        }
        print("[VoiceCommand] Engine started, listening for 'next' / 'back'...")
        return true
    }

    /// (Re)start ONLY the speech request+task; the audio engine keeps running underneath.
    private func startRecognition() {
        guard let recognizer, recognizer.isAvailable else { publish { self.available = false }; return }
        task?.cancel(); task = nil
        request?.endAudio(); request = nil

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // Privacy: keep recognition on-device so the mic audio never leaves the phone.
        req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        req.contextualStrings = ["next", "back", "next step", "go back", "previous", "forward"]
        request = req
        publish { self.isListening = true }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                // Surface the live transcript so the user can SEE it's hearing them.
                let text = result.bestTranscription.formattedString
                self.publish { if !self.suppressed { self.lastHeard = text } }
                self.handle(result.bestTranscription)
                if result.isFinal { self.restart() }
            }
            if error != nil { self.restart() }
        }
    }

    private func restart() {
        guard isListening, !suppressed else { return }
        // Engine stays up — just spin a fresh recognition request after a tiny debounce.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.isListening, !self.suppressed else { return }
            self.startRecognition()
        }
    }

    /// Restart recognition immediately after firing a command, so the just-heard word is cleared and
    /// can't fire a second time. The engine is untouched.
    private func hardRestart() {
        guard isListening else { return }
        startRecognition()
    }

    private func teardownAudio() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        lastConsumedIndex = 0
    }

    // MARK: Keyword & Command Matching

    /// Spot a command in the tail of the live transcription. Looking at the last few words (rather
    /// than tracking segment indices) is far more robust for short "next"/"back" utterances; after a
    /// hit we hard-restart so the same word can't re-fire. A time cooldown debounces doubles.
    private func handle(_ transcription: SFTranscription) {
        guard !suppressed else { return }
        let now = CACurrentMediaTime()
        guard now - lastFireTime >= cooldown else { return }

        let words = transcription.formattedString
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)
        let tail = Array(words.suffix(3))      // only the most recent words
        guard !tail.isEmpty else { return }

        if tail.contains(where: { isCommand($0, in: nextWords) }) {
            fireCommand(.next)
            hardRestart()
        } else if tail.contains(where: { isCommand($0, in: backWords) }) {
            fireCommand(.previous)
            hardRestart()
        }
    }

    /// Exact match, or within one edit (for words ≥4 chars) to tolerate a single mis-hear.
    private func isCommand(_ word: String, in set: Set<String>) -> Bool {
        if set.contains(word) { return true }
        guard word.count >= 4 else { return false }
        return set.contains { $0.count >= 4 && RecipeSearch.levenshtein(word, $0) <= 1 }
    }

    private func fireCommand(_ cmd: Command) {
        lastFireTime = CACurrentMediaTime()
        publish {
            self.lastHeard = cmd == .next ? "Next" : "Back"
            Haptics.tap()
            self.onCommand?(cmd)
        }
        // Keep the mascot floating and listening throughout the cook session!
        // Just clear the confirmation status after 1.8s so it says "Say Next or Back" again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.wakeActive else { return }
            self.publish {
                if self.lastHeard == "Next" || self.lastHeard == "Back" {
                    self.lastHeard = ""
                }
            }
        }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
