//
//  RepDetectorTests.swift
//  PaddleUpTests
//
//  Drives the real RepDetector with synthetic 30 fps pose streams. The body is
//  fixed so the normalisation scale is exactly 0.155 (torso 0.25 × 0.62), which
//  lets each wrist move be written directly as a speed in body-scales/second.
//

import CoreGraphics
import Foundation
import Testing
@testable import PaddleUp

/// Builds a synthetic pose stream for a right-handed player.
struct PoseStream {
    static let fps = 30.0
    static let bodyScale = 0.155

    private(set) var frames: [PoseFrame] = []
    var wrist = CGPoint(x: 0.62, y: 0.5)
    var bodyOffsetX = 0.0
    var confidence = 0.9

    /// Appends frames with the wrist held still.
    mutating func still(_ count: Int) {
        for _ in 0..<count { append(wristDX: 0, bodyDrift: 0) }
    }

    /// Appends one frame per speed; the wrist moves horizontally at that many
    /// body-scales/second (negative = backswing direction).
    mutating func move(_ speeds: [Double], bodyDrift: Double = 0) {
        for speed in speeds {
            append(wristDX: speed * Self.bodyScale / Self.fps, bodyDrift: bodyDrift)
        }
    }

    /// A textbook dink: back, reverse, accelerate to a 5.0 peak, decelerate, settle.
    mutating func cleanSwing(bodyDrift: Double = 0) {
        move(Array(repeating: -1.5, count: 6), bodyDrift: bodyDrift)
        move([2, 3, 4, 5, 3.4, 2, 1, 0.2], bodyDrift: bodyDrift)
        still(2)
    }

    private mutating func append(wristDX: Double, bodyDrift: Double) {
        wrist.x += wristDX
        bodyOffsetX += bodyDrift
        frames.append(makeFrame(time: Double(frames.count) / Self.fps))
    }

    private func makeFrame(time: Double) -> PoseFrame {
        let o = bodyOffsetX
        let c = confidence
        func p(_ x: Double, _ y: Double) -> PosePoint { PosePoint(x: x, y: y, confidence: c) }
        return PoseFrame(time: time, joints: [
            .nose: p(0.50 + o, 0.20),
            .leftShoulder: p(0.45 + o, 0.30), .rightShoulder: p(0.55 + o, 0.30),
            .leftElbow: p(0.42 + o, 0.42), .rightElbow: p(0.58 + o, 0.42),
            .leftWrist: p(0.40 + o, 0.50), .rightWrist: p(wrist.x, wrist.y),
            .leftHip: p(0.46 + o, 0.55), .rightHip: p(0.54 + o, 0.55),
            .leftKnee: p(0.46 + o, 0.72), .rightKnee: p(0.54 + o, 0.72),
            .leftAnkle: p(0.46 + o, 0.90), .rightAnkle: p(0.54 + o, 0.90)
        ])
    }
}

/// Everything the detector emitted while consuming a stream.
struct DetectorRun {
    var states: [RepState] = []
    var completed: [RepWindow] = []
    var rejected: [RepRejection] = []

    init(_ frames: [PoseFrame], detector: RepDetector) {
        for frame in frames {
            switch detector.ingest(frame) {
            case .stateChanged(let state): states.append(state)
            case .repCompleted(let window): completed.append(window)
            case .repRejected(let reason): rejected.append(reason)
            case .none: break
            }
        }
    }
}

struct RepDetectorStateTests {

    @Test func settlesIntoReadyAfterThreeStillFrames() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(3)
        _ = DetectorRun(stream.frames, detector: detector)
        #expect(detector.state == .idle)

        stream.still(1)
        _ = detector.ingest(stream.frames[3])
        #expect(detector.state == .ready)
    }

    @Test func cleanSwingWalksEveryPhaseInOrderAndCompletesOneRep() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.cleanSwing()

        let run = DetectorRun(stream.frames, detector: detector)

        #expect(run.states == [.ready, .backswing, .forwardSwing, .contactWindow, .followThrough])
        #expect(run.rejected.isEmpty)
        #expect(run.completed.count == 1)
        #expect(detector.state == .cooldown)
    }

    @Test func completedWindowPinsContactToPeakWristSpeed() throws {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.cleanSwing()

        let window = try #require(DetectorRun(stream.frames, detector: detector).completed.first)

        // Window starts 3 frames before the backswing (index 3), so the 5.0
        // peak at stream index 14 is window index 11; the forward swing
        // started at stream index 11 → window index 8.
        #expect(window.frames.count == 18)
        #expect(window.contactIndex == 11)
        #expect(window.forwardStartIndex == 8)
        #expect(abs(window.peakWristSpeed - 5.0) < 0.001)
        #expect(window.swingDirection.dx > 0.99)
        #expect(abs(window.duration - 17.0 / 30.0) < 0.001)
        #expect(window.detectionConfidence > 0.5 && window.detectionConfidence <= 1)
    }

    @Test func cooldownThenSecondSwingCountsAsSecondRep() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.cleanSwing()
        stream.still(15) // 0.35 s refractory period + 3 settle frames
        stream.cleanSwing()

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.completed.count == 2)
        #expect(run.rejected.isEmpty)
    }

    @Test func swingStartedDuringCooldownIsIgnored() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.cleanSwing()
        stream.cleanSwing() // starts immediately, inside the 0.35 s cooldown

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.completed.count == 1)
    }

    @Test func poseDropoutWhileReadyFallsBackToIdle() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.confidence = 0.25
        stream.still(1)

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.states == [.ready, .idle])
        #expect(detector.state == .idle)
    }

    @Test func resetReturnsToIdleMidSwing() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.move([-1.5, -1.5])
        _ = DetectorRun(stream.frames, detector: detector)
        #expect(detector.state == .backswing)

        detector.reset()
        #expect(detector.state == .idle)
    }
}

struct RepDetectorRejectionTests {

    @Test func backswingThatStallsIsRejectedAsTooSlow() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.move([-1.5])
        stream.still(8)

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.rejected == [.tooSlow])
        #expect(run.completed.isEmpty)
        #expect(detector.state == .ready)
    }

    @Test func slowDriftWithoutReversalIsRejectedAsTooLong() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.move(Array(repeating: -0.6, count: 90)) // > 2.6 s, never reverses

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.rejected.first == .tooLong)
        #expect(run.completed.isEmpty)
    }

    @Test func tinyFastFlickIsRejectedAsTooSmall() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.move([-1.5, -1.5])
        stream.move([2, 3, 2, 0.2]) // ~0.34 body-scales of wrist path, below 0.45
        stream.still(2)

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.rejected == [.tooSmall])
        #expect(run.completed.isEmpty)
    }

    @Test func swingWhileHipsTravelIsRejectedAsWalking() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.cleanSwing(bodyDrift: 0.015) // hips travel ~1.35 body-scales

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.rejected == [.walking])
        #expect(run.completed.isEmpty)
    }

    @Test func swingWithWristBelowKneesIsRejectedAsBallPickup() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.wrist.y = 0.90 // knees are at 0.72
        stream.still(5)
        stream.cleanSwing()

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.rejected == [.wristTooLow])
        #expect(run.completed.isEmpty)
    }

    @Test func confidenceDropMidSwingIsRejectedAsLowConfidence() {
        let detector = RepDetector(hand: .right)
        var stream = PoseStream()
        stream.still(5)
        stream.move([-1.5, -1.5])
        stream.confidence = 0.25 // joints still visible (≥ 0.2) but below 0.32
        stream.move([-1.5])

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.rejected == [.lowConfidence])
        #expect(detector.state == .ready)
    }

    @Test func leftHandedDetectorIgnoresRightWristSwing() {
        let detector = RepDetector(hand: .left)
        var stream = PoseStream()
        stream.still(5)
        stream.cleanSwing()

        let run = DetectorRun(stream.frames, detector: detector)
        #expect(run.completed.isEmpty)
        #expect(!run.states.contains(.backswing))
    }
}
