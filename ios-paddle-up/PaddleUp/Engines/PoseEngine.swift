//
//  PoseEngine.swift
//  PaddleUp
//
//  On-device pose estimation with Vision. Runs entirely on the phone: lower
//  latency, no cloud cost, and body-position data never leaves the device.
//

import AVFoundation
import CoreGraphics
import Foundation
import Vision

nonisolated protocol PoseEngineDelegate: AnyObject, Sendable {
    func poseEngine(_ engine: PoseEngine, didDetect frame: PoseFrame?)
}

/// Wraps `VNDetectHumanBodyPoseRequest` and converts Vision's bottom-left
/// normalised space into the app's top-left normalised space.
nonisolated final class PoseEngine: @unchecked Sendable {
    private let request = VNDetectHumanBodyPoseRequest()
    private let processingQueue = DispatchQueue(label: "app.paddleup.pose", qos: .userInitiated)
    private var startTime: CFTimeInterval?
    /// Process every Nth frame to keep thermals and battery in check.
    private let frameStride: Int
    private var frameCounter = 0
    private var isProcessing = false

    weak var delegate: PoseEngineDelegate?

    init(frameStride: Int = 2) {
        self.frameStride = max(1, frameStride)
        request.revision = VNDetectHumanBodyPoseRequestRevision1
    }

    func reset() {
        startTime = nil
        frameCounter = 0
    }

    /// Feed a camera sample buffer. Non-blocking; results arrive on the delegate.
    func process(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation) {
        frameCounter += 1
        guard frameCounter % frameStride == 0 else { return }
        guard !isProcessing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true
        let timestamp = CACurrentMediaTime()
        if startTime == nil { startTime = timestamp }
        let elapsed = timestamp - (startTime ?? timestamp)

        processingQueue.async { [weak self] in
            guard let self else { return }
            defer { self.isProcessing = false }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([self.request])
            } catch {
                self.delegate?.poseEngine(self, didDetect: nil)
                return
            }
            guard let observation = self.request.results?.first else {
                self.delegate?.poseEngine(self, didDetect: nil)
                return
            }
            let frame = Self.convert(observation: observation, time: elapsed)
            self.delegate?.poseEngine(self, didDetect: frame)
        }
    }

    /// Analyse a still image (used by the assessment importer and tests).
    static func analyze(cgImage: CGImage, time: TimeInterval) -> PoseFrame? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let observation = request.results?.first else { return nil }
        return convert(observation: observation, time: time)
    }

    /// Synchronous pose detection on one decoded video frame (uploaded-video
    /// analysis). Reuse `request` across frames to avoid re-allocating Vision state.
    static func detectPose(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                           time: TimeInterval, using request: VNDetectHumanBodyPoseRequest) -> PoseFrame? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first else { return nil }
        return convert(observation: observation, time: time)
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

    private static func convert(observation: VNHumanBodyPoseObservation, time: TimeInterval) -> PoseFrame {
        var joints: [PoseJoint: PosePoint] = [:]
        for (visionJoint, joint) in jointMap {
            guard let point = try? observation.recognizedPoint(visionJoint), point.confidence > 0.05 else { continue }
            // Vision's origin is bottom-left; the app uses top-left.
            joints[joint] = PosePoint(x: point.location.x,
                                      y: 1 - point.location.y,
                                      confidence: Double(point.confidence))
        }
        return PoseFrame(time: time, joints: joints)
    }
}
