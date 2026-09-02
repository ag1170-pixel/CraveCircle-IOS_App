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

    /// Transcribe an audio OR video file entirely on-device.
    /// `localeID` e.g. "en-US", "hi-IN" — the best-guess source language.
    static func transcribe(url: URL, localeID: String) async throws -> Output {
        let start = Date()
        let audioURL = try await audioFile(from: url)
        let locale = Locale(identifier: localeID)

        try await ensureAssetInstalled(for: locale)

        let audio = try AVAudioFile(forReading: audioURL)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)

        async let collected = transcriber.results.reduce(AttributedString()) { partial, result in
            var partial = partial
            partial += result.text
            return partial
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        if let lastSample = try await analyzer.analyzeSequence(from: audio) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        let text = String((try await collected).characters).trimmingCharacters(in: .whitespacesAndNewlines)
        return Output(text: text, localeID: localeID, seconds: Date().timeIntervalSince(start))
    }

    // MARK: - Helpers

    /// Extract an m4a audio track from a video; pass through if the URL is already audio-only.
    private static func audioFile(from url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        if videoTracks.isEmpty { return url }

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscribeError.exportFailed
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("cc-\(UUID().uuidString).m4a")
        export.outputURL = out
        export.outputFileType = .m4a
        await withCheckedContinuation { cont in
            export.exportAsynchronously { cont.resume() }
        }
        guard export.status == .completed else { throw TranscribeError.exportFailed }
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
