//
//  AnalysisAccuracyTests.swift
//  PaddleUpTests
//
//  Accuracy guarantees for the baseline assessment pipeline, shared by
//  "Record Live" and "Upload Video":
//   - geometry is true to life on non-square frames
//   - the same player is followed when others are in view
//   - smoothing removes standing jitter but keeps real swing speed
//   - uploaded footage analyses the arm that actually swings
//   - live and upload score identical swings identically
//

import CoreGraphics
import Foundation
import Testing
@testable import PaddleUp

private func person(x: Double, height: Double = 0.6, confidence: Double = 0.9,
                    time: TimeInterval = 0, aspect: Double = 1) -> PoseFrame {
    let top = 0.5 - height / 2
    func p(_ dx: Double, _ fy: Double) -> PosePoint {
        PosePoint(x: x + dx * height, y: top + fy * height, confidence: confidence)
    }
    return PoseFrame(time: time, joints: [
        .nose: p(0, 0.05), .neck: p(0, 0.15),
        .leftShoulder: p(-0.1, 0.18), .rightShoulder: p(0.1, 0.18),
        .leftWrist: p(-0.15, 0.5), .rightWrist: p(0.15, 0.5),
        .leftHip: p(-0.07, 0.5), .rightHip: p(0.07, 0.5),
        .leftKnee: p(-0.07, 0.75), .rightKnee: p(0.07, 0.75),
        .leftAnkle: p(-0.07, 1.0), .rightAnkle: p(0.07, 1.0)
    ], aspectRatio: aspect)
}

struct GeometryAccuracyTests {

    @Test func rightAngleElbowReadsNinetyDegreesOnPortraitVideo() throws {
        // A true 90° elbow filmed in a 9:16 portrait frame. Upper arm runs
        // straight down 0.1 frame heights; forearm runs sideways 0.1 frame
        // heights, which is 0.1 / 0.5625 in raw normalised x.
        let aspect = 9.0 / 16.0
        let frame = PoseFrame(time: 0, joints: [
            .rightShoulder: PosePoint(x: 0.5, y: 0.3, confidence: 0.9),
            .rightElbow: PosePoint(x: 0.5, y: 0.4, confidence: 0.9),
            .rightWrist: PosePoint(x: 0.5 + 0.1 / aspect, y: 0.4, confidence: 0.9)
        ], aspectRatio: aspect)
        let s = try #require(frame.shoulder(for: .right))
        let e = try #require(frame.elbow(for: .right))
        let w = try #require(frame.wrist(for: .right))
        #expect(abs(PoseGeometry.angle(s, e, w) - 90) < 0.001)
    }

    @Test func bodyMeasurementsDoNotDependOnFrameShape() {
        // The same physical body filmed portrait and landscape must give the
        // same body-relative proportions.
        func body(aspect: Double) -> PoseFrame {
            PoseFrame(time: 0, joints: [
                .leftShoulder: PosePoint(x: 0.5 - 0.06 / aspect, y: 0.3, confidence: 0.9),
                .rightShoulder: PosePoint(x: 0.5 + 0.06 / aspect, y: 0.3, confidence: 0.9),
                .leftHip: PosePoint(x: 0.5 - 0.04 / aspect, y: 0.5, confidence: 0.9),
                .rightHip: PosePoint(x: 0.5 + 0.04 / aspect, y: 0.5, confidence: 0.9)
            ], aspectRatio: aspect)
        }
        let portrait = body(aspect: 9.0 / 16.0)
        let landscape = body(aspect: 16.0 / 9.0)
        #expect(abs(portrait.shoulderWidth - landscape.shoulderWidth) < 1e-9)
        #expect(abs(portrait.bodyScale - landscape.bodyScale) < 1e-9)
        #expect(abs(portrait.shoulderWidth - 0.12) < 1e-9)
    }

    @Test func savedFramesWithoutAspectDecodeAsSquare() throws {
        let legacy = #"{"time":1.5,"joints":{"nose":{"x":0.5,"y":0.2,"confidence":0.9}}}"#
        let frame = try JSONDecoder().decode(PoseFrame.self, from: Data(legacy.utf8))
        #expect(frame.aspectRatio == 1)
        #expect(frame.time == 1.5)

        let roundTrip = try JSONDecoder().decode(
            PoseFrame.self, from: JSONEncoder().encode(PoseFrame(time: 0, joints: [:], aspectRatio: 0.5625)))
        #expect(roundTrip.aspectRatio == 0.5625)
    }

    @Test func overlayMatchesAspectFillCrop() {
        // A portrait 9:16 image aspect-filled into a wider 3:4 view overflows
        // vertically; the overlay must use the same crop.
        let rect = PoseSkeletonOverlay.imageRect(in: CGSize(width: 300, height: 400),
                                                 aspectRatio: 9.0 / 16.0, mode: .fill)
        #expect(abs(rect.width - 300) < 0.001)
        #expect(abs(rect.height - 300 * 16 / 9) < 0.001)
        #expect(rect.minY < 0)

        let fit = PoseSkeletonOverlay.imageRect(in: CGSize(width: 300, height: 400),
                                                aspectRatio: 16.0 / 9.0, mode: .fit)
        #expect(abs(fit.width - 300) < 0.001)
        #expect(fit.minY > 0)
    }
}

struct PlayerTrackerTests {

    @Test func locksOntoTheMostProminentPlayer() throws {
        var tracker = PlayerTracker()
        let near = person(x: 0.5, height: 0.7)
        let far = person(x: 0.2, height: 0.25)
        let selection = tracker.select(from: [far, near], at: 0)
        let pick = try #require(selection)
        #expect(pick.isNewLock)
        #expect(pick.frame == near)
    }

    @Test func keepsFollowingTheSamePlayerWhenSomeoneBiggerWalksIn() throws {
        var tracker = PlayerTracker()
        _ = tracker.select(from: [person(x: 0.4, height: 0.5)], at: 0)
        // A closer bystander appears on the right; our player barely moved.
        let ours = person(x: 0.42, height: 0.5, time: 0.07)
        let bystander = person(x: 0.8, height: 0.9, time: 0.07)
        let selection = tracker.select(from: [bystander, ours], at: 0.07)
        let pick = try #require(selection)
        #expect(!pick.isNewLock)
        #expect(pick.frame == ours)
    }

    @Test func ignoresAnotherPersonWhenOurPlayerDropsOutBriefly() {
        var tracker = PlayerTracker()
        _ = tracker.select(from: [person(x: 0.3, height: 0.5)], at: 0)
        // Only a distant stranger visible: no frame rather than a wrong one.
        #expect(tracker.select(from: [person(x: 0.85, height: 0.5)], at: 0.1) == nil)
    }

    @Test func reacquiresAfterALongGap() throws {
        var tracker = PlayerTracker()
        _ = tracker.select(from: [person(x: 0.3, height: 0.5)], at: 0)
        let selection = tracker.select(from: [person(x: 0.8, height: 0.5)], at: 2)
        let pick = try #require(selection)
        #expect(pick.isNewLock)
    }

    @Test func rejectsFragmentaryDetections() {
        var tracker = PlayerTracker()
        let fragment = PoseFrame(time: 0, joints: [
            .nose: PosePoint(x: 0.5, y: 0.2, confidence: 0.9),
            .neck: PosePoint(x: 0.5, y: 0.25, confidence: 0.9)
        ])
        #expect(tracker.select(from: [fragment], at: 0) == nil)
    }
}

struct PoseSmootherTests {

    @Test func removesStandingJitter() {
        var smoother = PoseSmoother()
        var rawTravel = 0.0, smoothTravel = 0.0
        var lastRaw: Double?, lastSmooth: Double?
        for i in 0..<60 {
            let raw = 0.5 + (i.isMultiple(of: 2) ? 0.004 : -0.004)
            let frame = PoseFrame(time: Double(i) / 15, joints: [.rightWrist: PosePoint(x: raw, y: 0.5, confidence: 0.9)])
            let x = smoother.smooth(frame).joints[.rightWrist]?.x ?? 0
            if let lastRaw { rawTravel += abs(raw - lastRaw) }
            if let lastSmooth, i > 5 { smoothTravel += abs(x - lastSmooth) }
            lastRaw = raw
            lastSmooth = x
        }
        #expect(smoothTravel < rawTravel * 0.5)
    }

    @Test func keepsMostOfARealSwing() {
        var smoother = PoseSmoother()
        // Still, then a fast 0.3-frame sweep over 4 frames at 15 fps.
        var xs: [Double] = Array(repeating: 0.4, count: 10)
        xs += [0.475, 0.55, 0.625, 0.7]
        xs += Array(repeating: 0.7, count: 10)
        var out: [Double] = []
        for (i, x) in xs.enumerated() {
            let frame = PoseFrame(time: Double(i) / 15, joints: [.rightWrist: PosePoint(x: x, y: 0.5, confidence: 0.9)])
            out.append(smoother.smooth(frame).joints[.rightWrist]?.x ?? 0)
        }
        let rawPeak = zip(xs, xs.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        let smoothPeak = zip(out, out.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        #expect(smoothPeak > rawPeak * 0.75)
        #expect(abs((out.last ?? 0) - 0.7) < 0.005)
    }
}

struct PaddleHandTests {

    private func stream(swingingHand: Handedness, swings: Int) -> [PoseFrame] {
        var frames: [PoseFrame] = []
        for i in 0..<(swings * 30) {
            let phase = sin(Double(i) / 30 * 2 * .pi)
            var f = person(x: 0.5, time: Double(i) / 15)
            let joint: PoseJoint = swingingHand == .right ? .rightWrist : .leftWrist
            if var wrist = f.joints[joint] { wrist.x += phase * 0.12; f.joints[joint] = wrist }
            frames.append(f)
        }
        return frames
    }

    @Test func keepsProfileHandWhenThatArmSwings() {
        let poses = stream(swingingHand: .right, swings: 4)
        #expect(VideoSessionAnalyzer.resolvePaddleHand(poses: poses, preferred: .right) == .right)
    }

    @Test func followsTheSwingingArmInMirroredFootage() {
        // Selfie/mirrored video: a right-hander's paddle arm is labelled left.
        let poses = stream(swingingHand: .left, swings: 4)
        #expect(VideoSessionAnalyzer.resolvePaddleHand(poses: poses, preferred: .right) == .left)
    }

    @Test func keepsProfileHandWhenThereIsNoRealSwinging() {
        let poses = (0..<60).map { person(x: 0.5, time: Double($0) / 15) }
        #expect(VideoSessionAnalyzer.resolvePaddleHand(poses: poses, preferred: .left) == .left)
    }
}

struct LiveUploadConsistencyTests {

    /// Three identical clean dinks. Each swing nets the wrist +11.6 speed-frames
    /// forward, so it drifts slowly back (below rest speed) to the same start
    /// point, then rests long enough for cooldown + settle even after smoothing.
    private func threeDinks() -> [PoseFrame] {
        var stream = PoseStream()
        stream.still(8)
        for _ in 0..<3 {
            stream.cleanSwing()
            stream.move(Array(repeating: -0.29, count: 40))
            stream.still(24)
        }
        return stream.frames
    }

    @Test func smoothedStreamStillDetectsEveryRep() {
        let processor = PoseStreamProcessor()
        let smoothed = threeDinks().compactMap { processor.process(candidates: [$0], at: $0.time) }
        let reps = VideoSessionAnalyzer.detectAndScore(poses: smoothed, shot: .forehandDink, hand: .right,
                                                       sessionID: UUID(), sessionStart: .now)
        #expect(reps.count == 3)
    }

    @Test func uploadScoresMatchTheLivePipeline() {
        // Live path: detector + RepPipeline, as PracticeEngine wires them.
        let processor = PoseStreamProcessor()
        let poses = threeDinks().compactMap { processor.process(candidates: [$0], at: $0.time) }
        let detector = RepDetector(hand: .right)
        var live: [RepRecord] = []
        for pose in poses {
            if case .repCompleted(let window) = detector.ingest(pose),
               let rep = RepPipeline.process(window: window, expected: .forehandDink, hand: .right,
                                             sessionID: UUID(), index: live.count + 1, timestamp: .now).scored?.rep {
                live.append(rep)
            }
        }

        let upload = VideoSessionAnalyzer.detectAndScore(poses: poses, shot: .forehandDink, hand: .right,
                                                         sessionID: UUID(), sessionStart: .now).map(\.rep)
        #expect(live.count == upload.count)
        #expect(live.map(\.score) == upload.map(\.score))
        #expect(live.map(\.dominantIssue) == upload.map(\.dominantIssue))
    }

    @Test func identicalSwingsScoreIdentically() {
        let processor = PoseStreamProcessor()
        let poses = threeDinks().compactMap { processor.process(candidates: [$0], at: $0.time) }
        let reps = VideoSessionAnalyzer.detectAndScore(poses: poses, shot: .forehandDink, hand: .right,
                                                       sessionID: UUID(), sessionStart: .now).map(\.rep)
        guard let first = reps.first else { Issue.record("No reps"); return }
        for rep in reps { #expect(abs(rep.score - first.score) <= 2) }
    }

    @Test func straightLegsAreCaughtAsTheKneeBendIssue() throws {
        // The synthetic player stands bolt upright (180° knees): the analysis
        // must score knee bend poorly, not hand out a perfect score.
        let processor = PoseStreamProcessor()
        let poses = threeDinks().compactMap { processor.process(candidates: [$0], at: $0.time) }
        let rep = try #require(VideoSessionAnalyzer.detectAndScore(
            poses: poses, shot: .forehandDink, hand: .right, sessionID: UUID(), sessionStart: .now).first?.rep)
        let knee = try #require(rep.mechanics.first { $0.mechanic == .kneeBend })
        #expect(knee.rawValue > 172)
        #expect(knee.score <= 50)
        #expect(rep.score < 100)
    }
}
