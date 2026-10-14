//
//  OnDeviceTranscriber.swift
//  CraveCircle (AICookBook)
//
//  On-device transcription using iOS 26's SpeechAnalyzer / SpeechTranscriber (Neural Engine,
//  no server, no model to ship). The server hands the app the reel's audio; the phone does the
//  heavy transcription here. Extracts audio from a video first when needed.
//

import Foundation
import AVFoundation
import Speech

enum OnDeviceTranscriber {

    struct Output {
        let text: String
        let localeID: String
        let seconds: Double
    }

    enum TranscribeError: Error { case exportFailed, notAuthorized, unsupportedLocale }

    /// Ask for speech-recognition permission (gates on-device transcription too).
    static func ensureAuthorized() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
    }

    /// All languages this device can transcribe on-device (BCP-47 ids), sorted.
    /// Used to offer every supported language, not a hardcoded few.
    static func supportedLocaleIDs() async -> [String] {
        let locales = await SpeechTranscriber.supportedLocales
        return locales.map { $0.identifier(.bcp47) }.sorted()
    }

    /// True if this device can transcribe the given language on-device.
    static func isSupported(localeID: String) async -> Bool {
        let target = Locale(identifier: localeID).identifier(.bcp47)
        let supported = await SpeechTranscriber.supportedLocales
        return supported.contains { $0.identifier(.bcp47) == target }
    }

    /// True when this file is already audio, so listening must not re-encode it.
    static func passesThroughAudio(pathExtension: String) -> Bool {
        ["m4a", "aac", "mp3", "wav", "caf", "aif", "aiff", "flac"].contains(pathExtension.lowercased())
    }

    /// Download/install the speech model for a locale. Call this when the user picks a recipe
    /// language — not from inside `transcribe`, so an import doesn't count setup as listening.
    static func isAssetInstalled(localeID: String) async -> Bool {
        let target = Locale(identifier: localeID).identifier(.bcp47)
        let installed = await SpeechTranscriber.installedLocales
        return installed.contains { $0.identifier(.bcp47) == target }
    }

    static func installAssetIfNeeded(localeID: String) async throws {
        try await ensureAssetInstalled(for: Locale(identifier: localeID))
    }

    /// Transcribe an audio OR video file entirely on-device.
    /// `localeID` e.g. "en-US", "hi-IN" — the source language to transcribe in.
    /// Assumes the speech model is already installed (language selection). Stops once the
    /// narration is already a recipe, or once `TranscriptListen.timeCapSeconds` is reached.
    static func transcribe(url: URL, localeID: String) async throws -> Output {
        let start = Date()
        let audioURL = try await audioFile(from: url)
        let capped = (try? prefixAudio(audioURL)) ?? audioURL
        defer { if capped != audioURL { try? FileManager.default.removeItem(at: capped) } }

        let locale = Locale(identifier: localeID)
        let audio = try AVAudioFile(forReading: capped)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let box = TranscriptBox()

        let collect = Task {
            do {
                for try await result in transcriber.results {
                    box.append(result.text)
                    let end = CMTimeGetSeconds(result.range.end)
                    if TranscriptListen.heardEnough(box.plain)
                        || (end.isFinite && end >= TranscriptListen.timeCapSeconds) {
                        box.stop()
                        await analyzer.cancelAndFinishNow()
                        break
                    }
                }
            } catch {
                // The results stream ends when analysis is cancelled.
            }
        }

        do {
            if let lastSample = try await analyzer.analyzeSequence(from: audio) {
                if !box.didStop {
                    try await analyzer.finalizeAndFinish(through: lastSample)
                }
            } else if !box.didStop {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            if box.plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !box.didStop {
                await collect.value
                throw error
            }
        }
        await collect.value

        let text = box.plain.trimmingCharacters(in: .whitespacesAndNewlines)
        return Output(text: text, localeID: localeID, seconds: Date().timeIntervalSince(start))
    }

    // MARK: - Helpers

    /// Extract an m4a from a video, capped so a long clip isn't exported in full.
    /// An audio file is returned as-is — no AVAssetExportSession.
    private static func audioFile(from url: URL) async throws -> URL {
        if passesThroughAudio(pathExtension: url.pathExtension) { return url }

        let asset = AVURLAsset(url: url)
        let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        if videoTracks.isEmpty { return url }

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscribeError.exportFailed
        }
        let duration = (try? await asset.load(.duration)) ?? .zero
        let seconds = CMTimeGetSeconds(duration)
        if seconds.isFinite, seconds > TranscriptListen.timeCapSeconds {
            export.timeRange = CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: TranscriptListen.timeCapSeconds, preferredTimescale: 600))
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("cc-\(UUID().uuidString).m4a")
        export.outputURL = out
        export.outputFileType = .m4a
        if #available(iOS 18.0, *) {
            await export.export()
            if export.error != nil { throw TranscribeError.exportFailed }
        } else {
            await withCheckedContinuation { cont in
                export.exportAsynchronously { cont.resume() }
            }
            guard export.status == .completed else { throw TranscribeError.exportFailed }
        }
        return out
    }

    /// Copy the first `timeCapSeconds` of an already-long audio file. Short files are returned unchanged.
    /// ponytail: PCM copy, not a smarter endpointing pass. Upgrade: stop the reader from the recognizer.
    private static func prefixAudio(_ url: URL) throws -> URL {
        let input = try AVAudioFile(forReading: url)
        let rate = input.processingFormat.sampleRate
        guard rate > 0 else { return url }
        let seconds = Double(input.length) / rate
        guard seconds > TranscriptListen.timeCapSeconds + 0.5 else { return url }

        let out = FileManager.default.temporaryDirectory.appendingPathComponent("cc-cap-\(UUID().uuidString).caf")
        let output = try AVAudioFile(forWriting: out, settings: input.processingFormat.settings)
        let chunk: AVAudioFrameCount = 16_384
        var remaining = AVAudioFramePosition(TranscriptListen.timeCapSeconds * rate)
        while remaining > 0 {
            let n = AVAudioFrameCount(min(AVAudioFramePosition(chunk), remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: n) else { break }
            try input.read(into: buffer, frameCount: n)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
            remaining -= AVAudioFramePosition(buffer.frameLength)
        }
        return out
    }

    /// Download/install the on-device model for this locale if it isn't already present.
    private static func ensureAssetInstalled(for locale: Locale) async throws {
        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            throw TranscribeError.unsupportedLocale
        }
        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) { return }

        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }
}

/// When to stop listening, and when a link import still needs the video file.
enum TranscriptListen {
    /// ponytail: a recipe that starts after this is cut. Upgrade: endpoint on speech, not a fixed cap.
    static let timeCapSeconds: Double = 90
    static let characterCap = 1600

    /// Ingredients and a few steps, or a long monologue. A few words is never enough.
    static func heardEnough(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count >= characterCap { return true }
        guard t.count >= 400 else { return false }
        return quantityHits(t) >= 3 && stepCueHits(t) >= 3
    }

    /// Caption or transcript already reads as a recipe (used to skip a video download).
    static func readsAsRecipe(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 80 else { return false }
        return quantityHits(t) >= 2 && stepCueHits(t) >= 2
    }

    /// Remote video for on-screen OCR. A caption or transcript that already reads as a recipe
    /// does not need OCR, even when a poster was saved. The cover frame is downloaded separately.
    static func needsVideoDownload(transcriptCount: Int, context: String, hasCover: Bool) -> Bool {
        if hasCover && transcriptCount >= 40 { return false }
        if hasCover && readsAsRecipe(context) { return false }
        return transcriptCount < 40 || !hasCover
    }

    private static let quantity = try? NSRegularExpression(
        pattern: #"(?i)\b(\d+([.,/]\d+)?|½|¼|¾|⅓|⅔|one|two|three|four|five)\s*(g|kg|mg|ml|l|oz|lb|lbs|cup|cups|tbsp|tbs|tablespoons?|tsp|teaspoons?|cloves?|slices?|cans?|pinch|sticks?|eggs?)\b"#)
    private static let stepCues = ["cook", "bake", "fry", "boil", "simmer", "roast", "grill", "saute",
                                   "stir", "mix", "whisk", "chop", "dice", "slice", "season", "heat",
                                   "pour", "serve", "blend", "marinate", "preheat", "garnish", "knead",
                                   "drain", "steam", "toss"]

    private static func quantityHits(_ text: String) -> Int {
        guard let quantity else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return quantity.numberOfMatches(in: text, range: range)
    }

    private static func stepCueHits(_ text: String) -> Int {
        let lower = text.lowercased()
        return stepCues.reduce(0) { n, word in
            n + (lower.range(of: "\\b\(word)", options: .regularExpression) != nil ? 1 : 0)
        }
    }
}

private final class TranscriptBox: @unchecked Sendable {
    private let lock = NSLock()
    private var text = AttributedString()
    private var stopped = false

    var plain: String {
        lock.lock(); defer { lock.unlock() }
        return String(text.characters)
    }
    var didStop: Bool {
        lock.lock(); defer { lock.unlock() }
        return stopped
    }
    func append(_ piece: AttributedString) {
        lock.lock(); text += piece; lock.unlock()
    }
    func stop() {
        lock.lock(); stopped = true; lock.unlock()
    }
}
