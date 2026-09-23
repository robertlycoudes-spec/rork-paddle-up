//
//  SetupCheckEvaluatorTests.swift
//  PaddleUpTests
//
//  Camera setup checks are guidance only. These pin the tolerant thresholds
//  and the body-part messaging.
//

import CoreGraphics
import Foundation
import Testing
@testable import PaddleUp

private func frame(confidence: Double = 0.8, dropping: Set<PoseJoint> = [],
                   scale: Double = 1) -> PoseFrame {
    // An upright right-handed player occupying the middle ~60% of the frame height.
    let layout: [PoseJoint: (Double, Double)] = [
        .nose: (0.5, 0.2), .neck: (0.5, 0.26),
        .leftShoulder: (0.44, 0.28), .rightShoulder: (0.56, 0.28),
        .leftElbow: (0.41, 0.38), .rightElbow: (0.6, 0.38),
        .leftWrist: (0.4, 0.46), .rightWrist: (0.63, 0.45),
        .root: (0.5, 0.5), .leftHip: (0.46, 0.5), .rightHip: (0.54, 0.5),
        .leftKnee: (0.46, 0.65), .rightKnee: (0.54, 0.65),
        .leftAnkle: (0.46, 0.8), .rightAnkle: (0.54, 0.8)
    ]
    var joints: [PoseJoint: PosePoint] = [:]
    for (joint, point) in layout where !dropping.contains(joint) {
        let y = 0.5 + (point.1 - 0.5) * scale
        joints[joint] = PosePoint(x: point.0, y: y, confidence: confidence)
    }
    return PoseFrame(time: 0, joints: joints)
}

struct SetupCheckEvaluatorTests {

    @Test func noFrameMeansNoPlayer() {
        #expect(!SetupCheckEvaluator.hasPlayer(nil))
        #expect(!SetupCheckEvaluator.hasPlayer(PoseFrame(time: 0, joints: [:])))
    }

    @Test func weakButRealPoseStillCountsAsPlayer() {
        // Dim lighting (0.3 confidence) is a warning, not a block.
        let dim = frame(confidence: 0.3)
        #expect(SetupCheckEvaluator.hasPlayer(dim))
        let checks = SetupCheckEvaluator.evaluate(frame: dim, hand: .right, recentCenters: [])
        #expect(checks.first { $0.id == "lighting" }?.status == .warning)
        #expect(checks.first { $0.id == "player" }?.status == .passing)
    }

    @Test func normalSetupPassesEverything() {
        let checks = SetupCheckEvaluator.evaluate(frame: frame(), hand: .right, recentCenters: [])
        #expect(checks.count == 6)
        #expect(checks.allSatisfy { $0.status == .passing })
    }

    @Test func missingFeetNamesTheFeet() {
        let cut = frame(dropping: [.leftAnkle, .rightAnkle])
        let checks = SetupCheckEvaluator.evaluate(frame: cut, hand: .right, recentCenters: [])
        let body = checks.first { $0.id == "fullBody" }
        #expect(body?.status == .warning)
        #expect(body?.guidance == "Your feet are out of frame")
    }

    @Test func missingLegsAndHeadAreBothNamed() {
        let cut = frame(dropping: [.leftAnkle, .rightAnkle, .leftKnee, .rightKnee, .nose, .neck])
        #expect(SetupCheckEvaluator.missingBodyParts(frame: cut, hand: .right) == ["head", "legs"])
        let checks = SetupCheckEvaluator.evaluate(frame: cut, hand: .right, recentCenters: [])
        #expect(checks.first { $0.id == "fullBody" }?.guidance == "Your head and legs are out of frame")
    }

    @Test func missingPaddleArmUsesHandedness() {
        let cut = frame(dropping: [.leftWrist])
        #expect(SetupCheckEvaluator.missingBodyParts(frame: cut, hand: .left) == ["paddle arm"])
        #expect(SetupCheckEvaluator.missingBodyParts(frame: cut, hand: .right).isEmpty)
    }

    @Test func distanceIsTolerant() {
        // A player filling only ~30% of the frame height is fine at court distance.
        let far = frame(scale: 0.5)
        let checks = SetupCheckEvaluator.evaluate(frame: far, hand: .right, recentCenters: [])
        #expect(checks.first { $0.id == "distance" }?.status == .passing)
    }

    @Test func smallHandheldWobbleIsStable() {
        let centers = (0..<10).map { CGPoint(x: 0.5 + Double($0 % 2) * 0.04, y: 0.5) }
        let checks = SetupCheckEvaluator.evaluate(frame: frame(), hand: .right, recentCenters: centers)
        #expect(checks.first { $0.id == "stable" }?.status == .passing)
    }
}
