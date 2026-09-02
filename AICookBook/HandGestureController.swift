//
//  HandGestureController.swift
//  CraveCircle (AICookBook)
//
//  Hands-free flashcard navigation. Runs the FRONT camera through Vision's
//  hand-pose detector and turns a left/right hand swipe (waved in front of the
//  propped-up phone) into next / previous events. No camera preview is shown —
//  the flashcard stays fully visible; only a small status indicator reflects tracking.
//
//  Works on a real device; the Simulator has no camera, so it reports
//  `cameraAvailable = false` and the flashcards fall back to touch swipes.
//

import AVFoundation
import Vision
import QuartzCore
import Combine

final class HandGestureController: NSObject, ObservableObject {
    enum Direction { case next, previous }

    // UI state (published on main)
    @Published private(set) var handDetected = false
    @Published private(set) var isRunning = false
    @Published private(set) var cameraAvailable = true
    @Published private(set) var permissionDenied = false
    @Published private(set) var handX: CGFloat? = nil        // normalized 0…1, for the indicator

    /// Fired on the main thread when a swipe is recognized.
    var onGesture: ((Direction) -> Void)?

    private let session = AVCaptureSession()
    private let videoQueue = DispatchQueue(label: "cravecircle.handpose.video")
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()

    // Swipe state — only touched on videoQueue.
    private var samples: [(t: CFTimeInterval, x: CGFloat)] = []
    private var lastFire: CFTimeInterval = 0

    // Tunables
    private let travelThreshold: CGFloat = 0.22   // net (signed) fraction of frame width for a swipe
    private let cooldown: CFTimeInterval = 0.9
    private let window: CFTimeInterval = 0.7
    private let minConfidentPoints = 6            // hand must be clearly visible, not a stray point
    private let jointConfidence: Float = 0.4

    // MARK: Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted { self.configureAndRun() }
                else { self.publish { self.permissionDenied = true } }
            }
        default:
            publish { self.permissionDenied = true }
        }
    }

    func stop() {
        videoQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        publish { self.isRunning = false; self.handDetected = false; self.handX = nil }
    }

    private func configureAndRun() {
        videoQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .medium

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                self.publish { self.cameraAvailable = false }
                return
            }
            self.session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: self.videoQueue)
            if self.session.canAddOutput(output) { self.session.addOutput(output) }

            self.session.commitConfiguration()
            self.session.startRunning()
            self.publish { self.cameraAvailable = true; self.isRunning = true; self.permissionDenied = false }
        }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    // MARK: Swipe detection (videoQueue)

    private func process(x: CGFloat, at t: CFTimeInterval) {
        samples.append((t, x))
        samples.removeAll { t - $0.t > window }
        guard samples.count >= 4, let first = samples.first, let last = samples.last,
              t - lastFire > cooldown else { return }

        let xs = samples.map(\.x)
        let displacement = last.x - first.x                      // net, signed movement
        let extent = (xs.max() ?? 0) - (xs.min() ?? 0)          // total spread across the window
        let magnitude = abs(displacement)

        // A real swipe is a decisive move in ONE direction — reject small moves and the
        // back-and-forth jitter that the old max−min test used to fire on.
        guard magnitude >= travelThreshold, extent > 0, magnitude >= 0.6 * extent else { return }

        // …and the frame-to-frame steps must mostly agree with the net direction.
        var agree = 0, total = 0
        for i in 1..<samples.count {
            let step = samples[i].x - samples[i - 1].x
            if abs(step) < 0.004 { continue }                    // ignore micro-jitter
            total += 1
            if (step > 0) == (displacement > 0) { agree += 1 }
        }
        guard total >= 2, Double(agree) / Double(total) >= 0.65 else { return }

        // Front camera is mirrored: a hand wiped to the user's right reads as increasing x.
        let dir: Direction = displacement > 0 ? .next : .previous
        lastFire = t
        samples.removeAll()
        publish { self.onGesture?(dir) }
    }

    private func clearSamples() { samples.removeAll() }
}

extension HandGestureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform([request])
            guard let hand = request.results?.first else {
                clearSamples()
                publish { self.handDetected = false; self.handX = nil }
                return
            }
            // Average all confident joints into a hand centroid — far steadier than the lone
            // wrist point the old version tracked, and it gates out half-seen / stray hands.
            let points = (try? hand.recognizedPoints(.all)) ?? [:]
            let confident = points.values.filter { $0.confidence > jointConfidence }
            guard confident.count >= minConfidentPoints else {
                clearSamples()
                publish { self.handDetected = false }
                return
            }
            let cx = confident.reduce(CGFloat(0)) { $0 + $1.location.x } / CGFloat(confident.count)
            let t = CACurrentMediaTime()
            process(x: cx, at: t)
            publish { self.handDetected = true; self.handX = cx }
        } catch {
            // Transient Vision failures are ignored; the next frame retries.
        }
    }
}
