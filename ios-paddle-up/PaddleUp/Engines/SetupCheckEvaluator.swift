//
//  SetupCheckEvaluator.swift
//  PaddleUp
//
//  Pure framing checks for camera setup. Every check is guidance only — the
//  single hard requirement to start is that a player is detected at all.
//  Thresholds are deliberately tolerant so ordinary court setups pass.
//

import CoreGraphics
import Foundation

/// One framing requirement evaluated live from the pose stream.
nonisolated struct SetupCheck: Identifiable, Sendable, Equatable {
    enum Status: Sendable, Equatable { case pending, warning, passing }

    let id: String
    let title: String
    let status: Status
    /// Live guidance shown when the check isn't passing.
    let guidance: String?
}

nonisolated enum SetupCheckEvaluator {

    /// Tolerances. Looser than the analyzer's own confidence floor on purpose:
    /// setup should coach, not gatekeep.
    enum Tolerance {
        static let playerMinConfidence = 0.2
        static let playerMinJoints = 5
        static let jointConfidence = 0.15
        static let minBodyHeight = 0.22
        static let maxBodyHeight = 0.97
        static let minCoverage = 0.7
        static let maxJitter = 0.12
        static let lightingConfidence = 0.35
    }

    static func pendingChecks() -> [SetupCheck] {
        [
            SetupCheck(id: "player", title: "Player detected", status: .pending, guidance: "Step into the frame"),
            SetupCheck(id: "fullBody", title: "Full body visible", status: .pending, guidance: nil),
            SetupCheck(id: "distance", title: "Far enough away", status: .pending, guidance: nil),
            SetupCheck(id: "stable", title: "Camera stable", status: .pending, guidance: nil),
            SetupCheck(id: "lighting", title: "Lighting acceptable", status: .pending, guidance: nil),
            SetupCheck(id: "orientation", title: "Orientation correct", status: .pending, guidance: nil)
        ]
    }

    /// The only hard gate: is there a person in the frame at all?
    static func hasPlayer(_ frame: PoseFrame?) -> Bool {
        guard let frame else { return false }
        let visible = frame.joints.values.filter { $0.confidence > Tolerance.playerMinConfidence }.count
        return visible >= Tolerance.playerMinJoints && frame.meanConfidence > Tolerance.playerMinConfidence
    }

    /// Evaluate all six checks for a frame that already contains a player.
    static func evaluate(frame: PoseFrame, hand: Handedness, recentCenters: [CGPoint]) -> [SetupCheck] {
        var results: [SetupCheck] = [
            SetupCheck(id: "player", title: "Player detected", status: .passing, guidance: nil)
        ]

        // Full body — name exactly which part is missing.
        let missing = missingBodyParts(frame: frame, hand: hand)
        let coverage = frame.framingCoverage
        var bodyGuidance = outOfFrameMessage(missing)
        if bodyGuidance == nil && coverage < Tolerance.minCoverage {
            bodyGuidance = "You're at the edge of the frame — step toward the middle"
        }
        results.append(SetupCheck(id: "fullBody", title: "Full body visible",
                                  status: bodyGuidance == nil ? .passing : .warning,
                                  guidance: bodyGuidance))

        // Distance — how much of the frame height the visible body fills.
        let bodyHeight = bodyHeightFraction(frame)
        var distanceGuidance: String?
        if bodyHeight > Tolerance.maxBodyHeight { distanceGuidance = "Move farther back" }
        else if bodyHeight < Tolerance.minBodyHeight { distanceGuidance = "Move closer to the camera" }
        results.append(SetupCheck(id: "distance", title: "Far enough away",
                                  status: distanceGuidance == nil ? .passing : .warning,
                                  guidance: distanceGuidance))

        // Stability — the whole skeleton drifting a lot means the phone moves.
        let stable = recentCenters.count < 6 || centerJitter(recentCenters) < Tolerance.maxJitter
        results.append(SetupCheck(id: "stable", title: "Camera stable",
                                  status: stable ? .passing : .warning,
                                  guidance: stable ? nil : "Hold the phone steady — prop it against something solid"))

        // Lighting — low light collapses joint confidence.
        let lighting = frame.meanConfidence > Tolerance.lightingConfidence
        results.append(SetupCheck(id: "lighting", title: "Lighting acceptable",
                                  status: lighting ? .passing : .warning,
                                  guidance: lighting ? nil : "It's a bit dark — brighter light helps tracking"))

        // Orientation — torso should read as upright.
        let upright = isUpright(frame)
        results.append(SetupCheck(id: "orientation", title: "Orientation correct",
                                  status: upright ? .passing : .warning,
                                  guidance: upright ? nil : "Stand the phone upright in portrait"))

        return results
    }

    /// Body parts the analyzer needs but can't see, in plain words.
    static func missingBodyParts(frame: PoseFrame, hand: Handedness) -> [String] {
        let minimum = Tolerance.jointConfidence
        var parts: [String] = []

        let hasHead = frame.point(.nose, minConfidence: minimum) != nil
            || frame.point(.neck, minConfidence: minimum) != nil
        if !hasHead { parts.append("head") }

        let paddleWrist: PoseJoint = hand == .right ? .rightWrist : .leftWrist
        if frame.point(paddleWrist, minConfidence: minimum) == nil { parts.append("paddle arm") }

        let hasFeet = frame.point(.leftAnkle, minConfidence: minimum) != nil
            || frame.point(.rightAnkle, minConfidence: minimum) != nil
        if !hasFeet {
            let hasKnees = frame.point(.leftKnee, minConfidence: minimum) != nil
                || frame.point(.rightKnee, minConfidence: minimum) != nil
            parts.append(hasKnees ? "feet" : "legs")
        }
        return parts
    }

    /// "Your feet are out of frame", "Your head and paddle arm are out of frame".
    static func outOfFrameMessage(_ parts: [String]) -> String? {
        guard let last = parts.last else { return nil }
        let list = parts.count == 1 ? last : parts.dropLast().joined(separator: ", ") + " and " + last
        let plural = parts.count > 1 || last == "feet" || last == "legs"
        return "Your \(list) \(plural ? "are" : "is") out of frame"
    }

    static func bodyHeightFraction(_ frame: PoseFrame) -> Double {
        let ys = frame.joints.values.filter { $0.confidence > 0.2 }.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return maxY - minY
    }

    static func centerJitter(_ centers: [CGPoint]) -> Double {
        guard centers.count > 2 else { return 0 }
        let xs = centers.map(\.x), ys = centers.map(\.y)
        return hypot((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    static func isUpright(_ frame: PoseFrame) -> Bool {
        guard let shoulders = frame.shoulderCenter, let hips = frame.hipCenter else { return true }
        return abs(hips.y - shoulders.y) > abs(hips.x - shoulders.x) * 0.8
    }
}
