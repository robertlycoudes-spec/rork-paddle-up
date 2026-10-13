//
//  MechanicsAnalyzer.swift
//  PaddleUp
//
//  Turns a window of pose frames into normalised, pose-derived measurements.
//  Everything is expressed in body-relative units (shoulder widths, torso
//  lengths, degrees) rather than raw pixels, so measurements survive changes in
//  player height, body proportions, camera distance and camera angle.
//

import CoreGraphics
import Foundation

/// A single normalised measurement plus the confidence we have in it.
nonisolated struct MechanicMeasurement: Sendable {
    let mechanic: MechanicID
    let value: Double
    let unit: String
    let confidence: Double
}

/// A detected swing: the pose frames plus the index of the contact frame.
nonisolated struct RepWindow: Sendable {
    let frames: [PoseFrame]
    /// Index into `frames` of the estimated contact moment.
    let contactIndex: Int
    /// Index where the forward swing began.
    let forwardStartIndex: Int
    let hand: Handedness
    /// 0...1 confidence that this was a genuine, cleanly-measured swing.
    let detectionConfidence: Double
    /// Peak wrist speed in body-scales per second.
    let peakWristSpeed: Double
    /// Unit vector of the forward swing in frame space.
    let swingDirection: CGVector

    var contactFrame: PoseFrame { frames[min(contactIndex, frames.count - 1)] }
    var duration: TimeInterval { (frames.last?.time ?? 0) - (frames.first?.time ?? 0) }
    /// Frames within ±0.18 s of contact. Contact is estimated from peak wrist
    /// speed, so the true contact moment can sit a frame or two off — sampling
    /// the neighborhood makes measurements robust to that.
    var contactNeighborhood: [PoseFrame] {
        guard let contact = frames[safe: contactIndex], !frames.isEmpty else { return frames }
        let low = contact.time - 0.18
        let high = contact.time + 0.18
        return frames.filter { $0.time >= low && $0.time <= high }
    }
}

nonisolated enum MechanicsAnalyzer {

    /// Measure every mechanic the rubric for `shot` asks for and that we can
    /// actually derive from pose today.
    static func measure(window: RepWindow, shot: ShotType, hand: Handedness) -> [MechanicMeasurement] {
        let rubric = RubricLibrary.rubric(for: shot)
        return rubric.measuredComponents.compactMap { component in
            measure(component.mechanic, window: window, hand: hand)
        }
    }

    static func measure(_ mechanic: MechanicID, window: RepWindow, hand: Handedness) -> MechanicMeasurement? {
        switch mechanic {
        case .kneeBend: return kneeBend(window)
        case .contactPosition: return contactPosition(window, hand: hand)
        case .armStructure: return armStructure(window, hand: hand)
        case .headStability: return headStability(window)
        case .followThrough: return followThrough(window, hand: hand)
        case .balance, .torsoStability: return balance(window, as: mechanic)
        case .weightTransfer: return weightTransfer(window)
        case .softHands: return softHands(window)
        case .stanceWidth: return stanceWidth(window)
        case .contactHeight: return contactHeight(window, hand: hand)
        case .movementConsistency: return nil
        default: return nil
        }
    }

    // MARK: - Sample helpers

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Individual mechanics

    /// Interior knee angle through contact, in degrees — the deepest flexion
    /// within the contact neighborhood, which is the loaded leg in an athletic
    /// base. A single-frame reading jumps around when Vision tracks a noisy
    /// joint, so the neighborhood keeps the grade stable and honest.
    private static func kneeBend(_ window: RepWindow) -> MechanicMeasurement? {
        var deepest: (angle: Double, confidence: Double)?
        for frame in window.contactNeighborhood {
            var angles: [Double] = []
            var confidences: [Double] = []

            for (hip, knee, ankle) in [(PoseJoint.leftHip, PoseJoint.leftKnee, PoseJoint.leftAnkle),
                                       (PoseJoint.rightHip, PoseJoint.rightKnee, PoseJoint.rightAnkle)] {
                guard let h = frame.point(hip), let k = frame.point(knee), let a = frame.point(ankle) else { continue }
                angles.append(PoseGeometry.angle(h, k, a))
                let c = [frame.joints[hip]?.confidence, frame.joints[knee]?.confidence, frame.joints[ankle]?.confidence]
                    .compactMap { $0 }
                confidences.append(c.reduce(0, +) / Double(max(1, c.count)))
            }

            guard let minAngle = angles.min() else { continue }
            let confidence = confidences.max() ?? 0.3
            if deepest == nil || minAngle < deepest!.angle { deepest = (minAngle, confidence) }
        }
        guard let deepest else { return nil }
        return MechanicMeasurement(mechanic: .kneeBend, value: deepest.angle, unit: "°", confidence: deepest.confidence)
    }

    /// How far in front of the torso contact happened, in shoulder widths.
    /// Takes the best reach across the contact neighborhood — the single
    /// contact frame can fall just short of the true reach extreme.
    private static func contactPosition(_ window: RepWindow, hand: Handedness) -> MechanicMeasurement? {
        var best: (reach: Double, confidence: Double)?
        for frame in window.contactNeighborhood {
            guard let wrist = frame.wrist(for: hand), let center = frame.shoulderCenter else { continue }
            let scale = frame.bodyScale
            guard scale > 0.01 else { continue }

            // Distance from the torso centre line to the wrist, measured along the
            // swing direction so it reads the same whether the camera is front-on
            // or side-on.
            let dx = wrist.x - center.x
            let dy = wrist.y - center.y
            let dir = window.swingDirection
            let alongSwing = abs(dx * dir.dx + dy * dir.dy)
            let lateral = abs(dx)
            let reach = max(alongSwing, lateral) / scale

            let confidence = min(
                frame.joints[hand == .right ? .rightWrist : .leftWrist]?.confidence ?? 0,
                frame.meanConfidence
            )
            if best == nil || reach > best!.reach { best = (reach, confidence) }
        }
        guard let best else { return nil }
        return MechanicMeasurement(mechanic: .contactPosition, value: best.reach,
                                   unit: "×shoulder", confidence: best.confidence)
    }

    /// Elbow angle of the paddle arm through contact, in degrees. The median
    /// across the contact neighborhood resists single-frame outliers.
    private static func armStructure(_ window: RepWindow, hand: Handedness) -> MechanicMeasurement? {
        var samples: [(angle: Double, confidence: Double)] = []
        for frame in window.contactNeighborhood {
            guard let shoulder = frame.shoulder(for: hand),
                  let elbow = frame.elbow(for: hand),
                  let wrist = frame.wrist(for: hand) else { continue }
            let joints: [PoseJoint] = hand == .right ? [.rightShoulder, .rightElbow, .rightWrist]
                                                     : [.leftShoulder, .leftElbow, .leftWrist]
            let confidence = joints.compactMap { frame.joints[$0]?.confidence }.min() ?? 0.3
            samples.append((PoseGeometry.angle(shoulder, elbow, wrist), confidence))
        }
        guard let angle = median(samples.map(\.angle)) else { return nil }
        let confidence = mean(samples.map(\.confidence)) ?? 0.3
        return MechanicMeasurement(mechanic: .armStructure, value: angle, unit: "°", confidence: confidence)
    }

    /// Total head travel across the swing, in shoulder widths. Lower is better.
    private static func headStability(_ window: RepWindow) -> MechanicMeasurement? {
        let points = window.frames.compactMap { $0.point(.nose, minConfidence: 0.25) }
        guard points.count >= 3 else { return nil }
        let scale = window.contactFrame.bodyScale
        guard scale > 0.01 else { return nil }

        // Bounding travel rather than path length, so tiny jitter in the pose
        // estimate does not accumulate into a false "unstable head" reading.
        let xs = points.map(\.x), ys = points.map(\.y)
        let spread = hypot((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
        let confidence = window.frames.compactMap { $0.joints[.nose]?.confidence }.reduce(0, +)
            / Double(max(1, window.frames.count))
        return MechanicMeasurement(mechanic: .headStability, value: spread / scale,
                                   unit: "×shoulder", confidence: confidence)
    }

    /// Wrist path length travelled after contact, in shoulder widths.
    private static func followThrough(_ window: RepWindow, hand: Handedness) -> MechanicMeasurement? {
        guard window.contactIndex < window.frames.count - 1 else { return nil }
        let after = window.frames[window.contactIndex...].compactMap { $0.wrist(for: hand) }
        guard after.count >= 2 else { return nil }
        let scale = window.contactFrame.bodyScale
        guard scale > 0.01 else { return nil }
        let length = PoseGeometry.pathLength(after) / scale
        return MechanicMeasurement(mechanic: .followThrough, value: length, unit: "×shoulder",
                                   confidence: window.contactFrame.meanConfidence)
    }

    /// Hip-centre travel across the swing, in shoulder widths. Lower is steadier.
    private static func balance(_ window: RepWindow, as mechanic: MechanicID) -> MechanicMeasurement? {
        let centers = window.frames.compactMap { mechanic == .torsoStability ? $0.shoulderCenter : $0.hipCenter }
        guard centers.count >= 3 else { return nil }
        let scale = window.contactFrame.bodyScale
        guard scale > 0.01 else { return nil }
        let xs = centers.map(\.x), ys = centers.map(\.y)
        let spread = hypot((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
        return MechanicMeasurement(mechanic: mechanic, value: spread / scale, unit: "×shoulder",
                                   confidence: window.contactFrame.meanConfidence)
    }

    /// Forward hip travel along the swing direction through contact.
    private static func weightTransfer(_ window: RepWindow) -> MechanicMeasurement? {
        guard let start = window.frames[safe: window.forwardStartIndex]?.hipCenter,
              let end = window.frames.last?.hipCenter else { return nil }
        let scale = window.contactFrame.bodyScale
        guard scale > 0.01 else { return nil }
        let dir = window.swingDirection
        let travel = ((end.x - start.x) * dir.dx + (end.y - start.y) * dir.dy) / scale
        return MechanicMeasurement(mechanic: .weightTransfer, value: travel, unit: "×shoulder",
                                   confidence: window.contactFrame.meanConfidence)
    }

    /// Peak wrist speed through contact, in shoulder widths per second.
    private static func softHands(_ window: RepWindow) -> MechanicMeasurement? {
        MechanicMeasurement(mechanic: .softHands, value: window.peakWristSpeed,
                            unit: "×shoulder/s", confidence: window.contactFrame.meanConfidence)
    }

    /// Ankle separation through contact, in shoulder widths. Median across the
    /// neighborhood, so one dropped ankle joint cannot distort the stance.
    private static func stanceWidth(_ window: RepWindow) -> MechanicMeasurement? {
        var samples: [(value: Double, confidence: Double)] = []
        for frame in window.contactNeighborhood {
            guard let l = frame.point(.leftAnkle), let r = frame.point(.rightAnkle) else { continue }
            let scale = frame.bodyScale
            guard scale > 0.01 else { continue }
            let confidence = min(frame.joints[.leftAnkle]?.confidence ?? 0, frame.joints[.rightAnkle]?.confidence ?? 0)
            samples.append((PoseGeometry.distance(l, r) / scale, confidence))
        }
        guard let width = median(samples.map(\.value)) else { return nil }
        let confidence = mean(samples.map(\.confidence)) ?? 0.3
        return MechanicMeasurement(mechanic: .stanceWidth, value: width,
                                   unit: "×shoulder", confidence: confidence)
    }

    /// Contact height relative to the hips, in torso lengths. Positive = above hips.
    private static func contactHeight(_ window: RepWindow, hand: Handedness) -> MechanicMeasurement? {
        var samples: [(value: Double, confidence: Double)] = []
        for frame in window.contactNeighborhood {
            guard let wrist = frame.wrist(for: hand), let hips = frame.hipCenter else { continue }
            let torso = frame.torsoLength
            guard torso > 0.01 else { continue }
            let confidence = frame.meanConfidence
            // Screen y grows downward, so invert to make "higher" positive.
            samples.append(((hips.y - wrist.y) / torso, confidence))
        }
        guard let height = median(samples.map(\.value)) else { return nil }
        let confidence = mean(samples.map(\.confidence)) ?? 0.3
        return MechanicMeasurement(mechanic: .contactHeight, value: height,
                                   unit: "×torso", confidence: confidence)
    }
}

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
