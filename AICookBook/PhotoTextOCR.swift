//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: PhotoTextOCR.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Optical Character Recognition engine reading recipe text from photos and cookbook pages.
//
// 2. ARCHITECTURAL ROLE:
//    Wraps Apple's Vision framework (VNRecognizeTextRequest) to extract text from images with high accuracy.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "PhotoTextOCR uses Apple's Vision framework to scan cookbook pages and handwritten family recipes. It performs on-device OCR and feeds the extracted text into our recipe parser."
//
// ==============================================================================
//

//
//  PhotoTextOCR.swift
//  CraveCircle (AICookBook)
//
//  Read text from a single photo (a written/printed recipe) with Vision, fully on-device.
//  Used by "Import from photo" in the Add-a-recipe sheet.
//

import Foundation
import Vision
import UIKit

enum PhotoTextOCR {
    /// OCR a photo into newline-joined text lines (top-to-bottom). "" on failure or no text.
    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    // Top-to-bottom (Vision origin is bottom-left, so sort by descending y).
                    .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                    .compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}
