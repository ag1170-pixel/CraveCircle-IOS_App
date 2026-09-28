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
