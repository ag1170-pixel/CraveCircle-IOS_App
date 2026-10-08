//
//  VoiceSearchController.swift
//  CraveCircle (AICookBook)
//
//  One-shot voice dictation for the search bar. Tap the mic → speak a dish → the live transcript
//  flows into the search query. Recognition runs on-device when the hardware supports it, so the
//  audio never leaves the phone. Auto-stops after a short silence (or tap the mic again to stop).
//

import Foundation
import Speech
import AVFoundation
import Combine

final class VoiceSearchController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    func toggle() { isRecording ? stop() : start() }

    func start() {
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            DispatchQueue.main.async {
                guard let self else { return }
                guard auth == .authorized else { self.permissionDenied = true; return }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else { self.permissionDenied = true; return }
                        self.begin()
                    }
                }
            }
        }
    }

    func stop() { finish() }

    // MARK: - Session

    private func begin() {
        guard let recognizer, recognizer.isAvailable else { return }
        transcript = ""
        // Audio-session + engine setup are synchronous XPC calls that can block the main thread for
        // hundreds of ms (watchdog hang). Run them OFF-MAIN; @Published state + the timer go to main.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let s = AVAudioSession.sharedInstance()
                try s.setCategory(.record, mode: .measurement, options: .duckOthers)
                try s.setActive(true, options: .notifyOthersOnDeactivation)
            } catch { return }

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.requiresOnDeviceRecognition = false   // reliability for short dictation
            self.request = req

            let node = self.audioEngine.inputNode
            node.removeTap(onBus: 0)
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { return }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            self.audioEngine.prepare()
            do { try self.audioEngine.start() } catch { return }

            DispatchQueue.main.async {
                self.isRecording = true
                Haptics.tap()
                self.armSilenceTimer()
                self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                    guard let self else { return }
                    if let result {
                        DispatchQueue.main.async {
                            self.transcript = result.bestTranscription.formattedString
                            self.armSilenceTimer()   // reset the silence countdown while speech flows
                        }
                        if result.isFinal { self.finish() }
                    }
                    if error != nil { self.finish() }
                }
            }
        }
    }

    /// Stop automatically after a brief pause so the user doesn't have to tap the mic again.
    private func armSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            self?.finish()
        }
    }

    private func finish() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.teardown()
            self.isRecording = false
        }
    }

    private func teardown() {
        silenceTimer?.invalidate(); silenceTimer = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        request?.endAudio()
        task?.cancel(); task = nil; request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
