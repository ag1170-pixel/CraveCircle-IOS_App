//
//  VoiceSearchController.swift
//  CraveCircle (AICookBook)
//
//  Search-bar dictation. Tap the mic and speak anything — a dish, an ingredient, a sentence.
//  Uses the same on-device dictation model as Notes when that language is installed, and the
//  system recognizer otherwise. The live transcript flows into the search field.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Pieces of a live dictation, keyed by when they were spoken, so a revised guess replaces
/// the earlier one instead of being stuck on the end.
struct DictationTranscript {
    private var pieces: [(start: Double, text: String)] = []

    mutating func absorb(start: Double, text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return joined }
        if let i = pieces.firstIndex(where: { abs($0.start - start) < 0.08 }) {
            pieces[i].text = clean
        } else {
            pieces.append((start, clean))
            pieces.sort { $0.start < $1.start }
        }
        return joined
    }

    var joined: String {
        pieces.map(\.text).joined(separator: " ")
    }
}

final class VoiceSearchController: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var transcript = ""

    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var heardSpeech = false
    private var stopping = false

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var committed = ""

    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var dictation = DictationTranscript()
    private var resultsTask: Task<Void, Never>?

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
        stopping = false
        heardSpeech = false
        transcript = ""
        committed = ""
        dictation = DictationTranscript()
        // Locale lookup, session activate, and engine start are synchronous XPC calls.
        // On the main thread they freeze the UI for the better part of a second.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let notes = await self.startNotesDictation()
            if !notes, !self.stopping { await self.startLegacy() }
        }
    }

    /// Notes-style on-device dictation. Returns false when that language model is not installed yet.
    private func startNotesDictation() async -> Bool {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: .current) else { return false }
        let installed = await DictationTranscriber.installedLocales
        let ready = installed.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
        if !ready {
            let id = locale.identifier(.bcp47)
            Task { try? await OnDeviceTranscriber.installAssetIfNeeded(localeID: id) }
            return false
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else { return false }
        guard !stopping, await openSession() else { return false }

        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, let converter = AVAudioConverter(from: inputFormat, to: format) else {
            await closeSession()
            return false
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        do { try await analyzer.prepareToAnalyze(in: format) } catch {
            await closeSession()
            return false
        }
        self.analyzer = analyzer

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let converted = Self.convert(buffer, with: converter, to: format) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            continuation.finish()
            await closeSession()
            return false
        }
        guard !stopping else {
            continuation.finish()
            await closeSession()
            return false
        }

        await MainActor.run {
            self.isRecording = true
            Haptics.tap()
            self.armSilenceTimer(firstWait: true)
        }
        resultsTask = Task { @MainActor in
            do {
                for try await result in transcriber.results {
                    let start = CMTimeGetSeconds(result.range.start)
                    let text = String(result.text.characters)
                    self.transcript = self.dictation.absorb(start: start, text: text)
                    self.heardSpeech = !self.transcript.isEmpty
                    self.armSilenceTimer(firstWait: false)
                }
            } catch {}
        }
        Task { try? await analyzer.start(inputSequence: stream) }
        return true
    }

    /// System recognizer for any words, in the phone's language. Restarts itself so a pause
    /// between phrases does not throw away the rest of the sentence.
    private func startLegacy() async {
        let current = Locale.current
        let chosen = SFSpeechRecognizer(locale: current)
        recognizer = (chosen?.isAvailable == true ? chosen : nil)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable, await openSession() else { return }

        let node = audioEngine.inputNode
        node.removeTap(onBus: 0)
        let format = node.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { await closeSession(); return }
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { await closeSession(); return }
        guard !stopping else { await closeSession(); return }

        await MainActor.run {
            self.isRecording = true
            Haptics.tap()
            self.armSilenceTimer(firstWait: true)
            self.openRecognition(recognizer)
        }
    }

    private func openRecognition(_ recognizer: SFSpeechRecognizer) {
        request?.endAudio()
        task?.cancel()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = false
        req.taskHint = .dictation
        req.addsPunctuation = true
        request = req
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let spoken = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    guard self.isRecording, !self.stopping else { return }
                    self.transcript = self.joined(self.committed, spoken)
                    self.heardSpeech = !self.transcript.isEmpty
                    self.armSilenceTimer(firstWait: false)
                    if result.isFinal, self.heardSpeech { self.commitAndContinue(recognizer) }
                }
            }
            if let error = error as NSError? {
                // 216/301 are our own cancel. 1110 is "no speech" — the pause timer ends the take.
                if error.code == 216 || error.code == 301 || error.code == 1110 { return }
                DispatchQueue.main.async {
                    guard self.isRecording, !self.stopping, self.heardSpeech else { return }
                    self.commitAndContinue(recognizer)
                }
            }
        }
    }

    private func commitAndContinue(_ recognizer: SFSpeechRecognizer) {
        committed = transcript
        openRecognition(recognizer)
    }

    private func joined(_ earlier: String, _ latest: String) -> String {
        let a = earlier.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        if b.hasPrefix(a) { return b }
        return a + " " + b
    }

    /// Category + activate never run on the main thread. `setActive` there is the hang
    /// (the runtime reports it around 600ms and the screen freezes until it returns).
    private func openSession() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        } catch {
            return false
        }
        if #available(iOS 27, *) {
            return await withCheckedContinuation { cont in
                session.activate(options: []) { ok, _ in cont.resume(returning: ok) }
            }
        }
        return (try? session.setActive(true, options: .notifyOthersOnDeactivation)) != nil
    }

    private func closeSession() async {
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 27, *) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                session.deactivate(options: [.notifyOthersOnDeactivation]) { _, _ in cont.resume() }
            }
        } else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// First wait is long enough to start a sentence. Later waits end the take after a real pause.
    private func armSilenceTimer(firstWait: Bool) {
        silenceTimer?.invalidate()
        let gap: TimeInterval = firstWait && !heardSpeech ? 12 : 2.8
        silenceTimer = Timer.scheduledTimer(withTimeInterval: gap, repeats: false) { [weak self] _ in
            self?.finish()
        }
    }

    private func finish() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording else { return }
            self.stopping = true
            self.isRecording = false
            self.silenceTimer?.invalidate()
            self.silenceTimer = nil
            self.request?.endAudio()
            self.inputContinuation?.finish()
            self.inputContinuation = nil
            let analyzer = self.analyzer
            self.analyzer = nil
            self.task?.cancel()
            self.task = nil
            self.request = nil
            self.resultsTask?.cancel()
            self.resultsTask = nil
            let engine = self.audioEngine
            Task.detached(priority: .userInitiated) {
                engine.inputNode.removeTap(onBus: 0)
                if engine.isRunning { engine.stop() }
                await analyzer?.cancelAndFinishNow()
                await self.closeSession()
            }
        }
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(capacity, 1)) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0 else { return nil }
        return out
    }
}
