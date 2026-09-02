//
//  VoiceCommandController.swift
//  CraveCircle (AICookBook)
//
//  Hands-free flashcard navigation by VOICE. Listens on-device (SFSpeechRecognizer +
//  AVAudioEngine) and fires .next / .previous when the cook says "next" or "back"
//  (and close synonyms). Runs alongside the hand-gesture controller — use either.
//  On-device recognition means the audio never leaves the phone.
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
    @Published private(set) var lastHeard = ""

    /// Fired on the main thread when a command word is heard.
    var onCommand: ((Command) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastFire: CFTimeInterval = 0
    private var processedWords = 0
    private let cooldown: CFTimeInterval = 0.7

    // Only whole-word matches count, so "context" never trips "next".
    private let nextWords: Set<String> = ["next", "forward", "skip", "continue", "go"]
    private let backWords: Set<String> = ["back", "previous", "prev", "before", "return", "repeat"]

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
        teardownAudio()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Session

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            available = false
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // playAndRecord so haptics/other audio still work; duck others while listening.
            try session.setCategory(.playAndRecord, mode: .measurement,
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
        if recognizer?.supportsOnDeviceRecognition == true { req.requiresOnDeviceRecognition = true }
        request = req
        processedWords = 0

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

    /// Recycle the recognizer so its buffer doesn't grow unbounded (SFSpeech caps ~1 min).
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

    // MARK: Command matching

    private func handle(_ transcription: SFTranscription) {
        let words = transcription.segments.map {
            $0.substring.lowercased().trimmingCharacters(in: .punctuationCharacters)
        }
        guard words.count > processedWords else { return }

        for word in words[processedWords...] {
            let now = CACurrentMediaTime()
            if now - lastFire < cooldown { continue }
            if nextWords.contains(word) {
                lastFire = now
                publish { self.onCommand?(.next) }
            } else if backWords.contains(word) {
                lastFire = now
                publish { self.onCommand?(.previous) }
            }
        }
        processedWords = words.count
        publish { self.lastHeard = words.suffix(3).joined(separator: " ") }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}
