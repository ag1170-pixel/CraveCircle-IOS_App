//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: ImageDownscale.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Image optimization and memory management utility for photo uploads.
//
// 2. ARCHITECTURAL ROLE:
//    Resizes and compresses large camera photos using ImageIO before uploading or caching to conserve memory.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "ImageDownscale uses low-level ImageIO APIs to downscale photos before memory allocation, preventing memory pressure spikes when processing camera captures."
//
// ==============================================================================
//

//
//  ImageDownscale.swift
//  CraveCircle (AICookBook)
//
//  Shrink recipe covers before they go to Storage. A grabbed video frame can be 1–2 MB at full
//  resolution; the cards render at ~170pt, so uploading full-size makes every feed image slow to
//  load. ImageIO thumbnailing downsamples without a full-size decode (cheap on memory + CPU).
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageDownscale {
    /// Downsample `data` so its long edge is at most `maxPixel`, re-encoded as JPEG at `quality`.
    /// Returns nil if the data isn't a decodable image.
    static func jpeg(from data: Data, maxPixel: Int = 720, quality: CGFloat = 0.6) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData,
                                                    [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // respect EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
