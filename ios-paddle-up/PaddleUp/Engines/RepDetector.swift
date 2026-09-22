//
//  RepDetector.swift
//  PaddleUp
//
//  Motion state machine that turns a continuous stream of pose frames into
//  discrete swing reps, with explicit rejection of non-swing motion.
//

import CoreGraphics
import Foundation

nonisolated enum RepState: String, Sendable, CaseIterable {
    case idle = "IDLE"
    case ready = "READY"
    case backswing = "BACKSWING"
    case forwardSwing = "FORWARD_SWING"
    case contactWindow = "CONTACT_WINDOW"
    case followThrough = "FOLLOW_THROUGH"
    case cooldown = "COOLDOWN"
}

/// Why a candidate swing was thrown away. Exposed in developer mode and used
/// to measure the false-positive rate.
nonisolated enum RepRejection: String, Sendable {
    case tooShort, tooLong, tooSlow, tooSmall, walking, lowConfidence, wristTooLow
}

nonisolated struct RepDetectorTuning: Sendable {
    /// Wrist speed (body-scales/sec) that starts a backswing.
    var motionStartSpeed: Double = 0.55
    /// Wrist speed that must be exceeded during the forward swing.
    var forwardSpeed: Double = 1.0
    /// Speed below which the swing is considered finished.
    var restSpeed: Double = 0.35
    /// Minimum peak speed for a candidate to count as a swing.
    var minimumPeakSpeed: Double = 1.2
    /// Minimum wrist path length in body scales.
    var minimumPathLength: Double = 0.45
    var minimumDuration: TimeInterval = 0.22
    var maximumDuration: TimeInterval = 2.6
    /// Refractory period after a rep before another can start.
    var cooldown: TimeInterval = 0.35
    /// Max hip travel allowed during a rep (filters walking).
    var maximumHipTravel: Double = 1.15
    var minimumPoseConfidence: Double = 0.32
    /// Direction reversal (degrees) required between backswing and forward swing.
    var reversalAngle: Double = 95
}

/// Result of feeding one frame to the detector.
nonisolated enum RepDetectorEvent: Sendable {
    case none
    case stateChanged(RepState)
    case repCompleted(RepWindow)
    case repRejected(RepRejection)
}

/// Stateful swing detector. Owned and driven by the practice engine on the
/// main actor; the maths is cheap enough that it costs nothing there.
nonisolated final class RepDetector {
    private(set) var state: RepState = .idle
    private(set) var tuning: RepDetectorTuning
    private let hand: Handedness

    private var buffer: [PoseFrame] = []
    private var speeds: [Double] = []
    private var candidateStartIndex: Int = 0
    private var forwardStartIndex: Int = 0
    private var peakSpeed: Double = 0
    private var peakSpeedIndex: Int = 0
    private var backswingVelocity: CGVector = .zero
    private var forwardVelocity: CGVector = .zero
    private var cooldownUntil: TimeInterval = 0
    private var stillFrames: Int = 0

    /// Live debug readouts for developer mode.
    private(set) var lastWristSpeed: Double = 0
    private(set) var lastConfidence: Double = 0

    private let maxBuffer = 180

    init(hand: Handedness, tuning: RepDetectorTuning = RepDetectorTuning()) {
        self.hand = hand
        self.tuning = tuning
    }

    func reset() {
        state = .idle
        buffer.removeAll()
        speeds.removeAll()
        peakSpeed = 0
        stillFrames = 0
    }

    func updateTuning(_ tuning: RepDetectorTuning) { self.tuning = tuning }

    /// Feed one pose frame. Returns what happened, if anything.
    func ingest(_ frame: PoseFrame) -> RepDetectorEvent {
        buffer.append(frame)
        if buffer.count > maxBuffer {
            let drop = buffer.count - maxBuffer
            buffer.removeFirst(drop)
            speeds.removeFirst(min(drop, speeds.count))
            candidateStartIndex = max(0, candidateStartIndex - drop)
            forwardStartIndex = max(0, forwardStartIndex - drop)
            peakSpeedIndex = max(0, peakSpeedIndex - drop)
        }

        let confidence = frame.meanConfidence
        lastConfidence = confidence

        guard buffer.count >= 2 else {
            speeds.append(0)
            return .none
        }

        let previous = buffer[buffer.count - 2]
        let dt = max(0.008, frame.time - previous.time)
        let scale = max(0.02, frame.bodyScale)

        guard let wrist = frame.wrist(for: hand), let previousWrist = previous.wrist(for: hand) else {
            speeds.append(0)
            if confidence < tuning.minimumPoseConfidence { return transition(to: .idle) }
            return .none
        }

        let velocity = CGVector(dx: (wrist.x - previousWrist.x) / dt / scale,
                                dy: (wrist.y - previousWrist.y) / dt / scale)
        let speed = hypot(velocity.dx, velocity.dy)
        speeds.append(speed)
        lastWristSpeed = speed

        if frame.time < cooldownUntil {
            return state == .cooldown ? .none : transition(to: .cooldown)
        }

        if confidence < tuning.minimumPoseConfidence {
            if state == .backswing || state == .forwardSwing || state == .contactWindow {
                return finish(rejecting: .lowConfidence)
            }
            return state == .idle ? .none : transition(to: .idle)
        }

        switch state {
        case .idle, .cooldown:
            stillFrames = speed < tuning.restSpeed ? stillFrames + 1 : 0
            if stillFrames >= 3 { return transition(to: .ready) }
            return .none

        case .ready:
            if speed > tuning.motionStartSpeed {
                candidateStartIndex = max(0, buffer.count - 3)
                peakSpeed = speed
                peakSpeedIndex = buffer.count - 1
                backswingVelocity = velocity
                return transition(to: .backswing)
            }
            return .none

        case .backswing:
            backswingVelocity = CGVector(dx: backswingVelocity.dx * 0.7 + velocity.dx * 0.3,
                                         dy: backswingVelocity.dy * 0.7 + velocity.dy * 0.3)
            if speed > peakSpeed { peakSpeed = speed; peakSpeedIndex = buffer.count - 1 }

            // A forward swing begins when the wrist reverses direction and accelerates.
            let reversal = angleBetween(backswingVelocity, velocity)
            if reversal > tuning.reversalAngle && speed > tuning.forwardSpeed {
                forwardStartIndex = buffer.count - 1
                forwardVelocity = velocity
                peakSpeed = speed
                peakSpeedIndex = buffer.count - 1
                return transition(to: .forwardSwing)
            }
            // A long slow drift without a reversal is not a swing.
            if buffer[buffer.count - 1].time - buffer[candidateStartIndex].time > tuning.maximumDuration {
                return finish(rejecting: .tooLong)
            }
            if speed < tuning.restSpeed {
                stillFrames += 1
                if stillFrames > 6 { return finish(rejecting: .tooSlow) }
            } else {
                stillFrames = 0
            }
            return .none

        case .forwardSwing:
            forwardVelocity = CGVector(dx: forwardVelocity.dx * 0.6 + velocity.dx * 0.4,
                                       dy: forwardVelocity.dy * 0.6 + velocity.dy * 0.4)
            if speed > peakSpeed { peakSpeed = speed; peakSpeedIndex = buffer.count - 1 }
            // Contact is the moment of peak wrist speed; we recognise it once
            // speed has decayed meaningfully from that peak.
            if speed < peakSpeed * 0.72 { return transition(to: .contactWindow) }
            if buffer[buffer.count - 1].time - buffer[candidateStartIndex].time > tuning.maximumDuration {
                return finish(rejecting: .tooLong)
            }
            return .none

        case .contactWindow:
            if speed < tuning.restSpeed { return transition(to: .followThrough) }
            if buffer[buffer.count - 1].time - buffer[candidateStartIndex].time > tuning.maximumDuration {
                return finish(rejecting: .tooLong)
            }
            return .none

        case .followThrough:
            stillFrames += 1
            if stillFrames >= 2 { return completeRep(endIndex: buffer.count - 1) }
            return .none
        }
    }

    // MARK: - Private

    private func transition(to newState: RepState) -> RepDetectorEvent {
        guard newState != state else { return .none }
        state = newState
        if newState == .ready || newState == .idle { stillFrames = 0 }
        if newState == .followThrough { stillFrames = 0 }
        return .stateChanged(newState)
    }

    private func finish(rejecting reason: RepRejection) -> RepDetectorEvent {
        state = .ready
        stillFrames = 0
        peakSpeed = 0
        return .repRejected(reason)
    }

    private func completeRep(endIndex: Int) -> RepDetectorEvent {
        let start = max(0, candidateStartIndex)
        guard endIndex > start else { return finish(rejecting: .tooShort) }
        let frames = Array(buffer[start...endIndex])
        guard frames.count >= 5 else { return finish(rejecting: .tooShort) }

        let duration = frames[frames.count - 1].time - frames[0].time
        if duration < tuning.minimumDuration { return finish(rejecting: .tooShort) }
        if duration > tuning.maximumDuration { return finish(rejecting: .tooLong) }
        if peakSpeed < tuning.minimumPeakSpeed { return finish(rejecting: .tooSlow) }

        let wristPoints = frames.compactMap { $0.wrist(for: hand) }
        let scale = max(0.02, frames[frames.count / 2].bodyScale)
        let pathLength = PoseGeometry.pathLength(wristPoints) / scale
        if pathLength < tuning.minimumPathLength { return finish(rejecting: .tooSmall) }

        // Walking / repositioning filter: the hips should stay roughly planted.
        let hips = frames.compactMap { $0.hipCenter }
        if hips.count >= 2 {
            let xs = hips.map(\.x), ys = hips.map(\.y)
            let travel = hypot((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0)) / scale
            if travel > tuning.maximumHipTravel { return finish(rejecting: .walking) }
        }

        let contactIndex = max(0, min(frames.count - 1, peakSpeedIndex - start))
        let contactFrame = frames[contactIndex]

        // Bending to pick up a ball looks like a swing but happens near the floor.
        if let wrist = contactFrame.wrist(for: hand), let knees = kneeLine(contactFrame),
           wrist.y > knees + 0.1 {
            return finish(rejecting: .wristTooLow)
        }

        let meanConfidence = frames.map(\.meanConfidence).reduce(0, +) / Double(frames.count)
        if meanConfidence < tuning.minimumPoseConfidence { return finish(rejecting: .lowConfidence) }

        let direction = normalized(forwardVelocity)
        let detectionConfidence = confidenceScore(meanConfidence: meanConfidence,
                                                  peakSpeed: peakSpeed,
                                                  pathLength: pathLength,
                                                  duration: duration)

        let window = RepWindow(
            frames: frames,
            contactIndex: contactIndex,
            forwardStartIndex: max(0, min(frames.count - 1, forwardStartIndex - start)),
            hand: hand,
            detectionConfidence: detectionConfidence,
            peakWristSpeed: peakSpeed,
            swingDirection: direction
        )

        cooldownUntil = (frames.last?.time ?? 0) + tuning.cooldown
        state = .cooldown
        stillFrames = 0
        peakSpeed = 0
        return .repCompleted(window)
    }

    private func kneeLine(_ frame: PoseFrame) -> Double? {
        let knees = [frame.point(.leftKnee), frame.point(.rightKnee)].compactMap { $0?.y }
        guard !knees.isEmpty else { return nil }
        return knees.reduce(0, +) / Double(knees.count)
    }

    private func confidenceScore(meanConfidence: Double, peakSpeed: Double,
                                 pathLength: Double, duration: TimeInterval) -> Double {
        let poseTerm = min(1, meanConfidence / 0.75)
        let speedTerm = min(1, peakSpeed / (tuning.minimumPeakSpeed * 1.8))
        let pathTerm = min(1, pathLength / (tuning.minimumPathLength * 2.2))
        let durationTerm = duration > 0.3 && duration < 1.9 ? 1.0 : 0.72
        return max(0.1, min(1, poseTerm * 0.45 + speedTerm * 0.25 + pathTerm * 0.2 + durationTerm * 0.1))
    }

    private func angleBetween(_ a: CGVector, _ b: CGVector) -> Double {
        let magA = hypot(a.dx, a.dy), magB = hypot(b.dx, b.dy)
        guard magA > 0.0001, magB > 0.0001 else { return 0 }
        let cosine = max(-1, min(1, (a.dx * b.dx + a.dy * b.dy) / (magA * magB)))
        return acos(cosine) * 180 / .pi
    }

    private func normalized(_ v: CGVector) -> CGVector {
        let mag = hypot(v.dx, v.dy)
        guard mag > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: v.dx / mag, dy: v.dy / mag)
    }
}
