import Foundation
import CoreGraphics
import QuartzCore

enum SwipeDirection {
    case left   // previous
    case right  // next
}

/// Detects a clean one-direction open-palm swipe.
///
/// Anti-confusion rules (why it won't fire randomly or bounce back):
///  1. Pose gate — only tracks while the hand is a flat open palm. Closing the
///     hand or losing the hand clears everything.
///  2. Distance — the palm must travel more than `distanceThreshold` across the
///     window.
///  3. Direction consistency — most of the small step-to-step moves must go the
///     SAME way. A wiggle or a back-and-forth sway is rejected, so only a
///     deliberate sweep in one direction fires.
///  4. Lockout — after a fire, it ignores everything for `cooldown` seconds AND
///     requires the hand to leave / palm to reopen fresh before the next swipe.
///     This is what stops the "return swing" from triggering the opposite way.
///
/// Coordinates arrive already mirrored to match what the user sees, so a hand
/// moving to the user's right increases x → `.right` → next.
final class SwipeDetector {

    // Tuning.
    var distanceThreshold: CGFloat = 0.25   // fraction of frame width to count as a swipe
    var windowSeconds: TimeInterval = 0.6    // sweep must complete within this
    var cooldown: TimeInterval = 1.2         // min seconds between fires
    var consistency: Double = 0.75           // fraction of steps that must share direction
    var minSamples = 4                       // need this many readings before deciding
    var invertDirection = false              // flip if left/right feel reversed

    private struct Sample { let time: TimeInterval; let x: CGFloat }
    private var samples: [Sample] = []
    private var lastFireTime: TimeInterval = -.greatestFiniteMagnitude
    /// After a fire we require the palm to disappear once before re-arming.
    private var armed = true

    func update(hand: DetectedHand?, now: TimeInterval = CACurrentMediaTime()) -> SwipeDirection? {
        // Pose gate. No open palm → clear buffer and re-arm for the next swipe.
        guard let hand, hand.isOpenPalm else {
            samples.removeAll()
            armed = true
            return nil
        }

        // Still in the lockout window after a previous fire.
        guard now - lastFireTime >= cooldown else { return nil }
        // Must have re-opened the palm since the last fire.
        guard armed else { return nil }

        samples.append(Sample(time: now, x: hand.center.x))
        samples.removeAll { now - $0.time > windowSeconds }

        guard samples.count >= minSamples,
              let first = samples.first, let last = samples.last else { return nil }

        let dt = last.time - first.time
        guard dt >= 0.08 else { return nil }

        let dx = last.x - first.x
        guard abs(dx) >= distanceThreshold else { return nil }

        // Direction consistency: most step-deltas must match the net direction.
        let deltas = zip(samples, samples.dropFirst()).map { $1.x - $0.x }
        let matching = deltas.filter { ($0 > 0) == (dx > 0) }.count
        guard !deltas.isEmpty,
              Double(matching) / Double(deltas.count) >= consistency else { return nil }

        // Fire once, then lock out until the palm reopens.
        lastFireTime = now
        armed = false
        samples.removeAll()

        let movingRight = dx > 0
        let right = invertDirection ? !movingRight : movingRight
        return right ? .right : .left
    }

    func reset() {
        samples.removeAll()
        lastFireTime = -.greatestFiniteMagnitude
        armed = true
    }
}
