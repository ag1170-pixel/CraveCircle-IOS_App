//
//  VideoThumbnail.swift
//  CraveCircle (AICookBook)
//
//  Grabs a representative still frame from an imported cooking video, so an on-device import gets
//  a real cover photo instead of the generic fallback. Runs on-device; the frame is saved locally
//  and referenced by the recipe's thumbnailUrl.
//

import Foundation
import AVFoundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Encodes runtime images (import thumbnails, picked photos) as HEIC — Apple's native format,
/// ~40–50% smaller than JPEG at the same quality — with a JPEG fallback for the rare device
/// that can't encode HEIC. Callers save with the returned `ext` so the file type is honest.
enum ImageEncoder {
    static func encode(_ image: UIImage, quality: CGFloat = 0.8) -> (data: Data, ext: String)? {
        if let heic = heic(image, quality: quality) { return (heic, "heic") }
        if let jpeg = image.jpegData(compressionQuality: quality) { return (jpeg, "jpg") }
        return nil
    }

    private static func heic(_ image: UIImage, quality: CGFloat) -> Data? {
        guard let cg = image.cgImage else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}

enum VideoThumbnail {
    /// Returns encoded image data (HEIC when supported, else JPEG) plus its file extension, for a
    /// frame ~15% into the clip (skips black intros, avoids the very end). Kept modest (≤800px)
    /// so a big library of imports stays storage-light; HEIC roughly halves the per-thumbnail cost.
    static func frame(from url: URL, maxDimension: CGFloat = 800, quality: CGFloat = 0.8) async -> (data: Data, ext: String)? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let total = CMTimeGetSeconds(duration)
        guard total.isFinite, total > 0 else { return nil }

        let seconds = max(0.5, min(total * 0.15, total - 0.1))
        let time = CMTime(seconds: seconds, preferredTimescale: 600)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 1, preferredTimescale: 600)

        guard let cg = try? await generator.image(at: time).image else { return nil }
        return ImageEncoder.encode(UIImage(cgImage: cg), quality: quality)
    }
}
