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
        SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()
    }()

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastFireTime: CFTimeInterval = 0
    private var wakeExpiryTime: TimeInterval = -1.0
    private let cooldown: CFTimeInterval = 0.8

    // Phonetic variations of Crave / Hey Crave (covers different accents & speech recognizer interpretations)
    private let wakeTriggers = [
        "hey crave", "hey creave", "hey krave", "hey brave", "hey grave",
        "crave", "creave", "krave", "brave", "hey circle"
    ]
    private let nextTriggers = ["next", "forward", "skip", "continue", "go next"]
    private let backTriggers = ["back", "previous", "prev", "return", "repeat", "go back"]

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
        let session = AVAudioSession.sharedInstance()
        let perm = session.recordPermission
        print("[VoiceCommand] Mic recordPermission: \(perm.rawValue)")
        switch perm {
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
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
        wakeActive = false
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
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
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
        req.requiresOnDeviceRecognition = false
        req.contextualStrings = ["Hey Crave", "Crave", "next", "back", "next step", "go back"]
        request = req
        wakeExpiryTime = -1.0

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
        print("[VoiceCommand] Engine started, listening for 'Hey Crave'...")

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.handle(result.bestTranscription)
                if result.isFinal { self.restart() }
            }
            if let error {
                print("[VoiceCommand] recognitionTask error: \(error.localizedDescription)")
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
    }

    // MARK: Keyword & Command Matching

    private func handle(_ transcription: SFTranscription) {
        let text = transcription.formattedString.lowercased()
        let segments = transcription.segments
        guard !segments.isEmpty else { return }

        let now = CACurrentMediaTime()
        let latestSegment = segments.last!
        let currentAudioTime = latestSegment.timestamp + latestSegment.duration

        // 1. Wake word detection: "Hey Crave" / "Crave" / "Hey Creave"
        var wakeHeard = false
        for trigger in wakeTriggers {
            if text.contains(trigger) {
                wakeHeard = true
                break
            }
        }

        if wakeHeard && !wakeActive {
            wakeActive = true
            wakeExpiryTime = currentAudioTime + 6.0 // 6 seconds active window
            print("[VoiceCommand] 🌟 WAKE WORD DETECTED: 'Hey Crave' activated!")
            publish {
                self.wakeActive = true
                self.lastHeard = "Hey Crave!"
                Haptics.select()
            }
        }

        // 2. Check if wake window has timed out
        if wakeActive && wakeExpiryTime > 0 && currentAudioTime > wakeExpiryTime {
            wakeActive = false
            print("[VoiceCommand] Wake window timed out, returning to standby")
            publish { self.wakeActive = false }
        }

        // 3. Command execution (Next / Back)
        if now - lastFireTime >= cooldown {
            let hasNext = nextTriggers.contains(where: { text.hasSuffix($0) || text.contains("\($0) ") || text.contains(" \($0)") })
            let hasBack = backTriggers.contains(where: { text.hasSuffix($0) || text.contains("\($0) ") || text.contains(" \($0)") })

            if wakeActive {
                if hasNext {
                    print("[VoiceCommand] 👉 Executing NEXT command")
                    fireCommand(.next)
                    return
                } else if hasBack {
                    print("[VoiceCommand] 👈 Executing BACK command")
                    fireCommand(.previous)
                    return
                }
            } else {
                // Direct intentional 2-word commands work even without prior wake word
                if text.contains("next step") || text.contains("go next") {
                    print("[VoiceCommand] 👉 Executing direct NEXT STEP command")
                    fireCommand(.next)
                    return
                } else if text.contains("go back") || text.contains("previous step") || text.contains("last step") {
                    print("[VoiceCommand] 👈 Executing direct GO BACK command")
                    fireCommand(.previous)
                    return
                }
            }
        }
    }

    private func fireCommand(_ cmd: Command) {
        lastFireTime = CACurrentMediaTime()
        wakeExpiryTime = -1.0
        publish {
            self.lastHeard = cmd == .next ? "Next" : "Back"
            Haptics.tap()
            self.onCommand?(cmd)
        }
        // Keep wakeActive true for 1.2s to show success animation on mascot, then tuck away
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.wakeActive = false
        }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
