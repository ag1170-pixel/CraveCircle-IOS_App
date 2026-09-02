//
//  VideoTextOCR.swift
//  CraveCircle (AICookBook)
//
//  Reads ON-SCREEN text from a cooking video, fully on-device with Vision. Many reels put the
//  whole recipe on screen (ingredient overlays, step captions) and have no narration and no
//  description — this rescues those: sample frames, OCR each, de-duplicate the repeated overlays.
//  Free, no server, no model to ship.
//

import Foundation
import AVFoundation
import Vision

enum VideoTextOCR {

    /// Sample up to `maxFrames` frames evenly across the clip and OCR them.
    /// Returns de-duplicated on-screen lines joined by newlines; "" on failure or no text.
    static func recognizeText(url: URL, maxFrames: Int = 14) async -> String {
        let asset = AVURLAsset(url: url)
        guard
            let duration = try? await asset.load(.duration)
        else { return "" }
        let total = CMTimeGetSeconds(duration)
        guard total.isFinite, total > 0 else { return "" }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1080, height: 1080)

        // One frame roughly every ~1.5s, capped — enough to catch rotating overlays.
        let count = max(1, min(maxFrames, Int(total / 1.5) + 1))
        let times: [CMTime] = (0..<count).map { i in
            let t = total * (Double(i) + 0.5) / Double(count)
            return CMTime(seconds: t, preferredTimescale: 600)
        }

        var seen = Set<String>()
        var lines: [String] = []
        for t in times {
            guard let cg = try? await cgImage(generator, at: t) else { continue }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            guard (try? handler.perform([request])) != nil else { continue }
            for obs in request.results ?? [] {
                guard let top = obs.topCandidates(1).first else { continue }
                let s = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = s.lowercased()
                guard s.count >= 3, !seen.contains(key) else { continue }
                seen.insert(key)
                lines.append(s)
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func cgImage(_ gen: AVAssetImageGenerator, at time: CMTime) async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            gen.generateCGImageAsynchronously(for: time) { image, _, error in
                if let image {
                    cont.resume(returning: image)
                } else {
                    cont.resume(throwing: error ?? NSError(domain: "VideoTextOCR", code: -1))
                }
            }
        }
    }
}
