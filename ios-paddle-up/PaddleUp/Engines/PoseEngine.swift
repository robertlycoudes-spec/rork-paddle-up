//
//  PoseEngine.swift
//  PaddleUp
//
//  On-device pose estimation with Vision. Runs entirely on the phone: lower
//  latency, no cloud cost, and body-position data never leaves the device.
//
//  Live frames go through the same `PoseStreamProcessor` (player tracking +
//  jitter smoothing) as uploaded videos, so both inputs feed the rep detector
//  identical, comparable pose streams.
//

import AVFoundation
import CoreGraphics
import Foundation
import QuartzCore
import Vision

nonisolated protocol PoseEngineDelegate: AnyObject, Sendable {
    /// `hostTime` is the capture timestamp on the host clock (the same clock
    /// as `CACurrentMediaTime`), used to line clips up with reps.
    func poseEngine(_ engine: PoseEngine, didDetect frame: PoseFrame?, hostTime: TimeInterval)
}

/// Wraps `VNDetectHumanBodyPoseRequest` and converts Vision's bottom-left
/// normalised space into the app's top-left normalised space.
nonisolated final class PoseEngine: @unchecked Sendable {
    private let request = VNDetectHumanBodyPoseRequest()
    private let processingQueue = DispatchQueue(label: "app.paddleup.pose", qos: .userInitiated)
    private let stream = PoseStreamProcessor()
    private let busyLock = NSLock()

    // Touched only on `processingQueue`.
    private var startTime: TimeInterval?
    // Touched only on the capture queue.
    private var frameCounter = 0
    // Guarded by `busyLock`.
    private var isProcessing = false

    /// Process every Nth frame to keep thermals and battery in check.
    private let frameStride: Int

    weak var delegate: PoseEngineDelegate?

    init(frameStride: Int = 2) {
        self.frameStride = max(1, frameStride)
        request.revision = VNDetectHumanBodyPoseRequestRevision1
    }

    func reset() {
        processingQueue.async { [weak self] in
            self?.startTime = nil
            self?.stream.reset()
        }
    }

    /// Feed a camera sample buffer. Non-blocking; results arrive on the delegate.
    func process(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        frameCounter += 1
        guard frameCounter % frameStride == 0 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        busyLock.lock()
        if isProcessing { busyLock.unlock(); return }
        isProcessing = true
        busyLock.unlock()

        // Use the capture timestamp, not the processing time, so wrist speeds
        // are measured against when the frame was actually taken.
        let presentation = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let hostTime = presentation.isFinite ? presentation : CACurrentMediaTime()

        processingQueue.async { [weak self] in
            guard let self else { return }
            defer {
                self.busyLock.lock()
                self.isProcessing = false
                self.busyLock.unlock()
            }
            if self.startTime == nil { self.startTime = hostTime }
            let elapsed = hostTime - (self.startTime ?? hostTime)
            let candidates = Self.detectCandidates(in: pixelBuffer, orientation: orientation,
                                                   time: elapsed, using: self.request)
            let frame = self.stream.process(candidates: candidates, at: elapsed)
            self.delegate?.poseEngine(self, didDetect: frame, hostTime: hostTime)
        }
    }

    /// Analyse a still image. Returns the most prominent person.
    static func analyze(cgImage: CGImage, time: TimeInterval) -> PoseFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        let aspect = Double(cgImage.width) / Double(max(1, cgImage.height))
        let frames = (request.results ?? []).map { convert(observation: $0, time: time, aspectRatio: aspect) }
        return frames.max { PlayerTracker.prominence($0) < PlayerTracker.prominence($1) }
    }

    /// Every person Vision finds in one frame. Callers pick the player to follow
    /// with a `PoseStreamProcessor`. Reuse `request` across frames.
    static func detectCandidates(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                                 time: TimeInterval, using request: VNDetectHumanBodyPoseRequest) -> [PoseFrame] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let aspect = uprightAspectRatio(width: CVPixelBufferGetWidth(pixelBuffer),
                                        height: CVPixelBufferGetHeight(pixelBuffer),
                                        orientation: orientation)
        return (request.results ?? []).map { convert(observation: $0, time: time, aspectRatio: aspect) }
    }

    /// Width ÷ height of the image as Vision sees it after applying `orientation`.
    static func uprightAspectRatio(width: Int, height: Int, orientation: CGImagePropertyOrientation) -> Double {
        let w = Double(max(1, width)), h = Double(max(1, height))
        switch orientation {
        case .left, .right, .leftMirrored, .rightMirrored: return h / w
        default: return w / h
        }
    }

    private static let jointMap: [VNHumanBodyPoseObservation.JointName: PoseJoint] = [
        .nose: .nose, .neck: .neck, .root: .root,
        .leftShoulder: .leftShoulder, .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow, .rightElbow: .rightElbow,
        .leftWrist: .leftWrist, .rightWrist: .rightWrist,
        .leftHip: .leftHip, .rightHip: .rightHip,
        .leftKnee: .leftKnee, .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle, .rightAnkle: .rightAnkle
    ]

    private static func convert(observation: VNHumanBodyPoseObservation, time: TimeInterval,
                                aspectRatio: Double) -> PoseFrame {
        var joints: [PoseJoint: PosePoint] = [:]
        for (visionJoint, joint) in jointMap {
            guard let point = try? observation.recognizedPoint(visionJoint), point.confidence > 0.05 else { continue }
            // Vision's origin is bottom-left; the app uses top-left.
            joints[joint] = PosePoint(x: point.location.x,
                                      y: 1 - point.location.y,
                                      confidence: Double(point.confidence))
        }
        return PoseFrame(time: time, joints: joints, aspectRatio: aspectRatio)
    }
}
