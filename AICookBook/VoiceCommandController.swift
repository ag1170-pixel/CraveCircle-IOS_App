//
//  VoiceCommandController.swift
//  CraveCircle (AICookBook)
//
//  Hands-free flashcard navigation by VOICE. Listens on-device (SFSpeechRecognizer +
//  AVAudioEngine) with hardware acoustic noise cancellation and "Hey Siri"-style
//  keyword activation ("Hey Crave, next" / "Hey Crave, back" / "Crave next").
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
    @Published private(set) var wakeActive = false
    @Published private(set) var lastHeard = ""

    /// Fired on the main thread when a command word is heard.
    var onCommand: ((Command) -> Void)?

    private let recognizer: SFSpeechRecognizer? = {
        if let current = SFSpeechRecognizer(locale: Locale.current), current.isAvailable {
            return current
        }
        return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastFireTime: CFTimeInterval = 0
    private var lastTriggeredAudioTime: TimeInterval = -1.0
    private var wakeExpiryAudioTime: TimeInterval = -1.0
    private let cooldown: CFTimeInterval = 0.8

    // Wake keywords (like "Hey Siri")
    private let wakeTriggers = ["hey crave", "crave", "hey circle", "circle"]
    // Direction commands
    private let nextTriggers: Set<String> = ["next", "forward", "skip", "continue"]
    private let backTriggers: Set<String> = ["back", "previous", "prev", "return", "repeat"]

    // MARK: Lifecycle

    func start() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            guard status == .authorized else {
                self.publish { self.permissionDenied = true; self.available = false }
                return
            }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    self.publish { self.permissionDenied = true; self.available = false }
                    return
                }
                self.publish { self.beginSession() }
            }
        }
    }

    func stop() {
        isListening = false
        wakeActive = false
        teardownAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Session Setup with Noise Cancellation

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            available = false
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // .voiceChat activates iOS hardware beamforming, acoustic echo cancellation,
            // and background noise suppression — crucial for noisy kitchen environments.
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            available = false
            return
        }
        startTask()
    }

    private func startTask() {
        teardownAudio()

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true {
            req.requiresOnDeviceRecognition = true
        }
        // Custom contextual strings help speech recognizer prioritize "crave", "next", "back"
        req.contextualStrings = ["Hey Crave", "Crave", "next", "back", "next step", "go back"]
        request = req
        lastTriggeredAudioTime = -1.0
        wakeExpiryAudioTime = -1.0

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            publish { self.available = false }
            return
        }
        publish { self.isListening = true }

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.handle(result.bestTranscription)
                if result.isFinal { self.restart() }
            }
            if error != nil { self.restart() }
        }
    }

    private func restart() {
        guard isListening else { return }
        teardownAudio()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
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
    }

    // MARK: Keyword & Command Matching

    private func handle(_ transcription: SFTranscription) {
        let segments = transcription.segments
        guard !segments.isEmpty else { return }

        let now = CACurrentMediaTime()
        var currentWake = wakeActive

        for i in 0..<segments.count {
            let seg = segments[i]
            // Skip segments already processed by a previous command
            if seg.timestamp < lastTriggeredAudioTime { continue }

            let rawWord = seg.substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if rawWord.isEmpty { continue }

            // 1. Check for Wake Word ("Hey Crave" / "Crave")
            var isWakeWord = (rawWord == "crave")
            if i > 0 {
                let prevWord = segments[i - 1].substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
                if prevWord == "hey" && (rawWord == "crave" || rawWord == "circle") {
                    isWakeWord = true
                }
            }

            if isWakeWord {
                currentWake = true
                wakeExpiryAudioTime = seg.timestamp + 5.0 // Active for 5s of speech
                publish {
                    self.wakeActive = true
                    self.lastHeard = "Hey Crave…"
                    Haptics.select()
                }
            }

            // Check if wake state has timed out
            if currentWake && seg.timestamp > wakeExpiryAudioTime {
                currentWake = false
                publish { self.wakeActive = false }
            }

            // 2. Multi-word direct commands ("next step", "go back")
            if i > 0 {
                let prevWord = segments[i - 1].substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
                let pair = "\(prevWord) \(rawWord)"
                if pair == "next step" || pair == "go next" {
                    if now - lastFireTime >= cooldown {
                        fireCommand(.next, audioTimestamp: seg.timestamp + seg.duration)
                        return
                    }
                } else if pair == "go back" || pair == "last step" || pair == "previous step" {
                    if now - lastFireTime >= cooldown {
                        fireCommand(.previous, audioTimestamp: seg.timestamp + seg.duration)
                        return
                    }
                }
            }

            // 3. Single-word command gated by wake word OR spoken clearly
            if currentWake {
                if nextTriggers.contains(rawWord) {
                    if now - lastFireTime >= cooldown {
                        fireCommand(.next, audioTimestamp: seg.timestamp + seg.duration)
                        return
                    }
                } else if backTriggers.contains(rawWord) {
                    if now - lastFireTime >= cooldown {
                        fireCommand(.previous, audioTimestamp: seg.timestamp + seg.duration)
                        return
                    }
                }
            }
        }

        publish {
            self.lastHeard = segments.suffix(2).map(\.substring).joined(separator: " ")
        }
    }

    private func fireCommand(_ cmd: Command, audioTimestamp: TimeInterval) {
        lastFireTime = CACurrentMediaTime()
        lastTriggeredAudioTime = audioTimestamp
        wakeExpiryAudioTime = -1.0
        publish {
            self.wakeActive = false
            self.lastHeard = cmd == .next ? "Next" : "Back"
            Haptics.tap()
            self.onCommand?(cmd)
        }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

