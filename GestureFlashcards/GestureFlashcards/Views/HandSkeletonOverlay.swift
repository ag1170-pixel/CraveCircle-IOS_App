import SwiftUI

/// Draws the detected joint points over the camera preview.
/// Points are normalized (0…1) in the same mirrored space as the preview.
struct HandSkeletonOverlay: View {
    let points: [CGPoint]
    let isOpenPalm: Bool

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(isOpenPalm ? Color.green : Color.yellow)
                    .frame(width: 8, height: 8)
                    .position(x: p.x * geo.size.width,
                              y: p.y * geo.size.height)
            }
        }
        .allowsHitTesting(false)
    }
}
