import Vision
import CoreVideo
import CoreGraphics

/// A lightweight summary of the detected hand, in a screen-like coordinate
/// space: x in [0,1] left→right as the user sees it, y in [0,1] top→bottom.
struct DetectedHand: Equatable {
    /// Center of the palm (average of wrist + finger MCP joints).
    let center: CGPoint
    /// Number of extended fingers (0…5).
    let extendedFingers: Int
    /// True when the hand looks like a flat, open palm.
    let isOpenPalm: Bool
    /// All confident joint points, for the skeleton overlay.
    let points: [CGPoint]
}

/// Runs VNDetectHumanHandPoseRequest on a pixel buffer and boils the result
/// down to a `DetectedHand`.
final class HandPoseProcessor {

    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()

    private let minConfidence: Float = 0.5

    func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> DetectedHand? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }
        guard let all = try? observation.recognizedPoints(.all) else { return nil }

        // Vision origin is bottom-left, y up. Flip y so it reads top-down like a screen.
        func pt(_ name: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let p = all[name], p.confidence >= minConfidence else { return nil }
            return CGPoint(x: p.location.x, y: 1 - p.location.y)
        }

        guard let wrist = pt(.wrist) else { return nil }

        // Collect any confident joints for the overlay.
        let overlayPoints: [CGPoint] = all.values
            .filter { $0.confidence >= minConfidence }
            .map { CGPoint(x: $0.location.x, y: 1 - $0.location.y) }

        // Palm center: wrist plus the four finger MCPs (knuckles), averaged.
        let mcpNames: [VNHumanHandPoseObservation.JointName] =
            [.indexMCP, .middleMCP, .ringMCP, .littleMCP]
        var centerPoints = [wrist]
        for n in mcpNames { if let p = pt(n) { centerPoints.append(p) } }
        let center = centerPoints.averagePoint()

        // Finger extension: a finger is "extended" when its tip is meaningfully
        // farther from the wrist than its PIP joint (mirrors the web classifier).
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(a.x - b.x, a.y - b.y)
        }
        func fingerExtended(tip: VNHumanHandPoseObservation.JointName,
                            pip: VNHumanHandPoseObservation.JointName) -> Bool {
            guard let t = pt(tip), let p = pt(pip) else { return false }
            return dist(wrist, t) > dist(wrist, p) * 1.05
        }

        let index  = fingerExtended(tip: .indexTip,  pip: .indexPIP)
        let middle = fingerExtended(tip: .middleTip, pip: .middlePIP)
        let ring   = fingerExtended(tip: .ringTip,   pip: .ringPIP)
        let little = fingerExtended(tip: .littleTip, pip: .littlePIP)

        // Thumb: extended when the tip sits well away from the index MCP.
        var thumb = false
        if let tTip = pt(.thumbTip), let idxMCP = pt(.indexMCP), let mMCP = pt(.middleMCP) {
            let scale = max(dist(idxMCP, mMCP), 0.0001)
            thumb = dist(tTip, idxMCP) > scale * 1.4
        }

        let extended = [thumb, index, middle, ring, little].filter { $0 }.count
        // Open palm: at least the four fingers extended (thumb optional).
        let isOpen = index && middle && ring && little

        return DetectedHand(center: center,
                            extendedFingers: extended,
                            isOpenPalm: isOpen,
                            points: overlayPoints)
    }
}

private extension Array where Element == CGPoint {
    func averagePoint() -> CGPoint {
        guard !isEmpty else { return .zero }
        let sum = reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    }
}
