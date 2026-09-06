import AVFoundation
import Vision
import Combine
import UIKit

/// Owns the AVCaptureSession (front camera), pumps sample buffers into the
/// hand-pose processor, and republishes results on the main thread.
final class CameraManager: NSObject, ObservableObject {

    /// Latest detected hand (nil when no hand is visible).
    @Published var hand: DetectedHand?
    /// True while the session is running.
    @Published var isRunning = false
    /// Human-readable status for the UI ("Show your palm", errors, etc.).
    @Published var statusText = "Starting camera…"

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let processor = HandPoseProcessor()

    // Throttle Vision so we don't run it on every single frame.
    private var lastProcessTime = Date.distantPast
    private let minFrameInterval: TimeInterval = 1.0 / 20.0   // ~20 Hz

    // MARK: Lifecycle

    func start() {
        requestAuthorization { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.statusText = "Camera access denied. Enable it in Settings." }
                return
            }
            self.sessionQueue.async {
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.statusText = "Show an open palm, then swipe left or right."
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    // MARK: Permission

    private func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { completion($0) }
        default:
            completion(false)
        }
    }

    // MARK: Configuration

    private var configured = false
    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.statusText = "No front camera available." }
            return
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        // Leave the data-output buffer as the raw sensor image (landscape, un-mirrored).
        // We correct rotation + mirroring for Vision via CGImagePropertyOrientation
        // (.leftMirrored) so it isn't applied twice. The on-screen preview mirrors
        // itself for the front camera, which is what the user expects to see.
        if let conn = videoOutput.connection(with: .video), conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = false
        }

        session.commitConfiguration()
    }
}

// MARK: - Frame handling

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= minFrameInterval else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Front camera in portrait: .leftMirrored gives an upright, mirrored image
        // whose normalized X matches what the user sees on screen.
        let detected = processor.process(pixelBuffer: pixelBuffer, orientation: .leftMirrored)

        DispatchQueue.main.async {
            self.hand = detected
        }
    }
}
