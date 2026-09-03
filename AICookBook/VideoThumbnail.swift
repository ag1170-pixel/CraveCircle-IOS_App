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

enum VideoThumbnail {
    /// Returns JPEG data for a frame ~15% into the clip (skips black intros, avoids the very end).
    static func jpeg(from url: URL, maxDimension: CGFloat = 1080, quality: CGFloat = 0.85) async -> Data? {
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
        return UIImage(cgImage: cg).jpegData(compressionQuality: quality)
    }
}
