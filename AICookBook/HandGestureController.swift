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
import CoreGraphics

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
    
    private let processor = HandPoseProcessor()
    private let swipeDetector = SwipeDetector()

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
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: self.videoQueue)
            
            if self.session.canAddOutput(output) { self.session.addOutput(output) }
            
            // Adjust mirroring explicitly for front camera
            if let conn = output.connection(with: .video), conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = false
            }

            self.session.commitConfiguration()
            self.session.startRunning()
            self.publish { self.cameraAvailable = true; self.isRunning = true; self.permissionDenied = false }
        }
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

extension HandGestureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let detected = processor.process(pixelBuffer: pixelBuffer, orientation: .leftMirrored)
        
        // Detect swipes using the new SwipeDetector
        let swipeDir = swipeDetector.update(hand: detected, now: CACurrentMediaTime())
        
        if let swipeDir = swipeDir {
            let mappedDir: Direction = swipeDir == .right ? .next : .previous
            publish {
                self.onGesture?(mappedDir)
            }
        }
        
        publish {
            if let hand = detected {
                self.handDetected = true
                self.handX = hand.center.x
            } else {
                self.handDetected = false
                self.handX = nil
            }
        }
    }
}
