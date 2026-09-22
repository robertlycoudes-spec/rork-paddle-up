//
//  ShotClassifier.swift
//  PaddleUp
//
//  Classifies a detected swing into a shot type from normalised pose features.
//
//  SCOPE: this is a deterministic feature-rule classifier, not a trained model.
//  It reliably separates forehand from backhand and rejects swings whose shape
//  clearly does not match the session's shot. It does NOT attempt open-set
//  classification across all 15 shot types — during a practice session the
//  player has already told us which shot they are drilling, so the classifier's
//  real job is side detection plus a plausibility check.
//

import CoreGraphics
import Foundation

nonisolated struct ShotClassification: Sendable {
    let shot: ShotType
    /// 0...1 confidence in the assignment.
    let confidence: Double
    /// True when the swing did not look like the shot the session expected.
    let mismatchesExpectation: Bool
}

nonisolated enum ShotClassifier {

    /// Classify within the context of the session's selected shot.
    static func classify(window: RepWindow, hand: Handedness, expected: ShotType) -> ShotClassification {
        let side = detectSide(window: window, hand: hand)
        let resolved = resolve(expected: expected, isForehandSide: side.isForehand)
        let plausibility = plausibility(window: window, shot: resolved)

        let confidence = max(0.15, min(1, side.confidence * 0.6 + plausibility * 0.4))
        return ShotClassification(
            shot: resolved,
            confidence: confidence,
            mismatchesExpectation: plausibility < 0.35
        )
    }

    /// Which side of the body the swing happened on, relative to the paddle hand.
    /// A backhand crosses the body's centre line; a forehand stays outside it.
    private static func detectSide(window: RepWindow, hand: Handedness) -> (isForehand: Bool, confidence: Double) {
        let frame = window.contactFrame
        guard let wrist = frame.wrist(for: hand),
              let center = frame.shoulderCenter,
              let paddleShoulder = frame.shoulder(for: hand) else {
            return (true, 0.3)
        }

        // Positive when the wrist sits on the same side as the paddle shoulder.
        let shoulderOffset = paddleShoulder.x - center.x
        let wristOffset = wrist.x - center.x
        let scale = max(0.02, frame.bodyScale)
        let alignment = (shoulderOffset * wristOffset) / (scale * scale)

        let isForehand = alignment >= 0
        // Confidence grows with how decisively the wrist sits on one side.
        let magnitude = min(1, abs(alignment) / 0.35)
        return (isForehand, max(0.35, magnitude))
    }

    private static func resolve(expected: ShotType, isForehandSide: Bool) -> ShotType {
        switch expected {
        case .forehandDink, .backhandDink:
            return isForehandSide ? .forehandDink : .backhandDink
        case .forehandDrive, .backhandDrive:
            return isForehandSide ? .forehandDrive : .backhandDrive
        case .forehandVolley, .backhandVolley:
            return isForehandSide ? .forehandVolley : .backhandVolley
        default:
            // Single-sided shots (serve, drop, reset, ...) keep their identity.
            return expected
        }
    }

    /// How well the swing's shape matches the expected shot's signature.
    private static func plausibility(window: RepWindow, shot: ShotType) -> Double {
        let frame = window.contactFrame
        let scale = max(0.02, frame.bodyScale)
        let speed = window.peakWristSpeed
        let wristPath = PoseGeometry.pathLength(window.frames.compactMap { $0.wrist(for: window.hand) }) / scale

        // Relative contact height: positive above the hips.
        var heightTerm = 0.6
        if let wrist = frame.wrist(for: window.hand), let hips = frame.hipCenter, frame.torsoLength > 0.01 {
            let relative = (hips.y - wrist.y) / frame.torsoLength
            heightTerm = score(relative, ideal: idealContactHeight(for: shot), tolerance: 0.7)
        }

        let speedTerm = score(speed, ideal: idealSpeed(for: shot), tolerance: idealSpeed(for: shot) * 0.9)
        let pathTerm = score(wristPath, ideal: idealPath(for: shot), tolerance: idealPath(for: shot) * 0.95)

        return max(0, min(1, heightTerm * 0.4 + speedTerm * 0.35 + pathTerm * 0.25))
    }

    private static func score(_ value: Double, ideal: Double, tolerance: Double) -> Double {
        guard tolerance > 0 else { return 0.5 }
        return max(0, 1 - abs(value - ideal) / tolerance)
    }

    /// Signature contact height per shot, in torso lengths above the hips.
    private static func idealContactHeight(for shot: ShotType) -> Double {
        switch shot {
        case .forehandDink, .backhandDink, .reset: return 0.05
        case .thirdShotDrop: return 0.0
        case .serve: return -0.15
        case .forehandVolley, .backhandVolley, .block, .rollVolley, .speedUp: return 0.55
        case .overhead, .lob: return 1.05
        default: return 0.3
        }
    }

    private static func idealSpeed(for shot: ShotType) -> Double {
        switch shot {
        case .forehandDink, .backhandDink, .reset, .block: return 2.0
        case .thirdShotDrop, .serve: return 3.2
        case .forehandVolley, .backhandVolley, .rollVolley: return 3.6
        case .forehandDrive, .backhandDrive, .speedUp, .overhead: return 5.5
        default: return 3.5
        }
    }

    private static func idealPath(for shot: ShotType) -> Double {
        switch shot {
        case .forehandDink, .backhandDink, .reset, .block: return 1.5
        case .thirdShotDrop, .serve: return 2.6
        case .forehandVolley, .backhandVolley, .rollVolley: return 1.9
        case .forehandDrive, .backhandDrive, .speedUp, .overhead: return 3.4
        default: return 2.4
        }
    }
}
