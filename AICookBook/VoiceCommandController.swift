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

    // Words that trigger navigation
    private let nextWords: Set<String> = [
        "next", "forward", "skip", "continue", "advance"
    ]
    private let backWords: Set<String> = [
        "back", "previous", "prev", "last", "reverse", "return", "repeat", "beck", "pack"
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
        startTask()
    }

    private func startTask() {
        teardownAudio()

        guard let recognizer, recognizer.isAvailable else {
            publish { self.available = false }
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // Privacy: keep recognition on-device so the mic audio never leaves the phone.
        // Falls back to server only on the rare device without on-device support.
        req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        req.contextualStrings = ["Hey Crave", "Crave", "next", "back", "next step", "go back", "previous"]
        request = req
        lastConsumedIndex = 0

        let node = audioEngine.inputNode
        node.removeTap(onBus: 0)
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            publish {
                self.available = false
                self.lastHeard = "Invalid audio format"
            }
            return
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            publish {
                self.available = false
                self.lastHeard = "Engine start error"
            }
            return
        }
        publish { self.isListening = true }
        print("[VoiceCommand] Engine started, listening for 'next' / 'back'...")

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.handle(result.bestTranscription)
                if result.isFinal { self.restart() }
            }
            if error != nil {
                self.restart()
            }
        }
    }

    private func restart() {
        guard isListening else { return }
        teardownAudio()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.isListening else { return }
            self.startTask()
        }
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

    private func handle(_ transcription: SFTranscription) {
        let segments = transcription.segments
        guard segments.count > lastConsumedIndex else { return }

        let now = CACurrentMediaTime()
        let newSegments = Array(segments[lastConsumedIndex...])
        
        var localWakeActive = self.wakeActive

        for (offset, seg) in newSegments.enumerated() {
            let word = seg.substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if word.isEmpty { continue }

            let globalIndex = lastConsumedIndex + offset

            // 1. Check for Wake Word: "crave", "creave", "krave", "brave" or "hey crave"
            var isWake = (word == "crave" || word == "creave" || word == "krave" || word == "brave")
            if !isWake && offset > 0 {
                let prev = newSegments[offset - 1].substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if prev == "hey" && (word == "crave" || word == "circle" || word == "creave") {
                    isWake = true
                }
            }

            if isWake && !localWakeActive {
                localWakeActive = true
                print("[VoiceCommand] 🌟 WAKE WORD: 'Hey Crave' activated! Staying open for entire cook session.")
                publish {
                    self.wakeActive = true
                    self.lastHeard = "Hey Crave!"
                    Haptics.select()
                }
            }

            // 2. Direct two-word commands: "next step", "go back", "step back", "previous step"
            if offset > 0 && now - lastFireTime >= cooldown {
                let prev = newSegments[offset - 1].substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
                let pair = "\(prev) \(word)"
                if pair == "next step" || pair == "go next" {
                    print("[VoiceCommand] 👉 Executing direct NEXT STEP command")
                    DispatchQueue.main.async { self.lastConsumedIndex = globalIndex + 1 }
                    fireCommand(.next)
                    return
                } else if pair == "go back" || pair == "previous step" || pair == "last step" || pair == "step back" {
                    print("[VoiceCommand] 👈 Executing direct GO BACK command")
                    DispatchQueue.main.async { self.lastConsumedIndex = globalIndex + 1 }
                    fireCommand(.previous)
                    return
                }
            }

            // 3. Single command words when wakeActive is true (stays active!)
            if localWakeActive && now - lastFireTime >= cooldown {
                if nextWords.contains(word) {
                    print("[VoiceCommand] 👉 Executing NEXT command (word: '\(word)')")
                    DispatchQueue.main.async { self.lastConsumedIndex = globalIndex + 1 }
                    fireCommand(.next)
                    return
                } else if backWords.contains(word) {
                    print("[VoiceCommand] 👈 Executing BACK command (word: '\(word)')")
                    DispatchQueue.main.async { self.lastConsumedIndex = globalIndex + 1 }
                    fireCommand(.previous)
                    return
                }
            }
        }
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
