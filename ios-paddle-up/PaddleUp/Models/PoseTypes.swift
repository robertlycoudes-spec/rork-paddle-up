//
//  PoseTypes.swift
//  PaddleUp
//
//  Framework-agnostic pose representation. Joints are stored normalised to the
//  frame (0...1) with a TOP-LEFT origin, so y grows downward like screen space.
//
//  Geometry never uses those raw values directly: frames aren't square, so a
//  normalised x unit and y unit are different physical lengths. `point(_:)`
//  returns aspect-corrected coordinates (both axes in frame heights) so angles
//  and distances are true to life on portrait live video and landscape uploads
//  alike.
//

import CoreGraphics
import Foundation

nonisolated enum PoseJoint: String, Codable, CaseIterable, Sendable {
    case nose, neck, root
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle

    var isLeft: Bool { rawValue.hasPrefix("left") }
}

nonisolated struct PosePoint: Codable, Sendable, Equatable {
    var x: Double
    var y: Double
    var confidence: Double

    var cg: CGPoint { CGPoint(x: x, y: y) }
}

/// One detected body pose at a moment in time.
nonisolated struct PoseFrame: Codable, Sendable, Equatable {
    /// Seconds since session start.
    var time: TimeInterval
    /// Raw normalised joint positions (0...1 on each axis).
    var joints: [PoseJoint: PosePoint]
    /// Width ÷ height of the upright image the pose was detected in.
    var aspectRatio: Double

    init(time: TimeInterval, joints: [PoseJoint: PosePoint], aspectRatio: Double = 1) {
        self.time = time
        self.joints = joints
        self.aspectRatio = aspectRatio > 0 && aspectRatio.isFinite ? aspectRatio : 1
    }

    /// Aspect-corrected position (both axes in frame heights). Use for all
    /// measurement maths.
    func point(_ joint: PoseJoint, minConfidence: Double = 0.2) -> CGPoint? {
        guard let p = joints[joint], p.confidence >= minConfidence else { return nil }
        return CGPoint(x: p.x * aspectRatio, y: p.y)
    }

    /// Raw normalised position, for drawing over the image.
    func displayPoint(_ joint: PoseJoint, minConfidence: Double = 0.2) -> CGPoint? {
        guard let p = joints[joint], p.confidence >= minConfidence else { return nil }
        return p.cg
    }

    /// Centre of the confidently tracked joints (aspect-corrected), used to
    /// follow one player across frames.
    var bodyCenter: CGPoint? {
        let points = PoseJoint.allCases.compactMap { point($0, minConfidence: 0.2) }
        guard points.count >= 4 else { return nil }
        let x = points.reduce(0) { $0 + $1.x } / Double(points.count)
        let y = points.reduce(0) { $0 + $1.y } / Double(points.count)
        return CGPoint(x: x, y: y)
    }

    /// Vertical extent of the confidently tracked joints, in frame heights.
    var apparentHeight: Double {
        let ys = joints.values.filter { $0.confidence > 0.2 }.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return maxY - minY
    }

    /// Mean confidence across the joints that matter for swing mechanics.
    var meanConfidence: Double {
        let keys: [PoseJoint] = [.leftShoulder, .rightShoulder, .leftHip, .rightHip,
                                 .leftKnee, .rightKnee, .leftWrist, .rightWrist, .nose]
        let values = keys.compactMap { joints[$0]?.confidence }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Distance between shoulders — the app's normalisation unit. Using a body
    /// dimension instead of raw pixels keeps scores comparable across player
    /// heights, camera distances and phone models.
    var shoulderWidth: Double {
        guard let l = point(.leftShoulder), let r = point(.rightShoulder) else { return 0 }
        return hypot(l.x - r.x, l.y - r.y)
    }

    var shoulderCenter: CGPoint? {
        guard let l = point(.leftShoulder), let r = point(.rightShoulder) else { return nil }
        return CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
    }

    var hipCenter: CGPoint? {
        guard let l = point(.leftHip), let r = point(.rightHip) else { return nil }
        return CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
    }

    /// Shoulder-centre to hip-centre distance; the vertical normalisation unit.
    var torsoLength: Double {
        guard let s = shoulderCenter, let h = hipCenter else { return 0 }
        return hypot(s.x - h.x, s.y - h.y)
    }

    /// Normalisation scale that tolerates a player turned side-on to the camera
    /// (shoulder width collapses, torso length does not).
    var bodyScale: Double {
        let shoulder = shoulderWidth
        let torso = torsoLength
        if shoulder > 0.02 && torso > 0.02 { return max(shoulder, torso * 0.62) }
        if torso > 0.02 { return torso * 0.62 }
        return max(shoulder, 0.02)
    }

    func wrist(for hand: Handedness) -> CGPoint? {
        point(hand == .right ? .rightWrist : .leftWrist)
    }

    func elbow(for hand: Handedness) -> CGPoint? {
        point(hand == .right ? .rightElbow : .leftElbow)
    }

    func shoulder(for hand: Handedness) -> CGPoint? {
        point(hand == .right ? .rightShoulder : .leftShoulder)
    }

    /// Fraction of the body that is inside the frame, used by camera setup.
    var framingCoverage: Double {
        let pts = joints.values.filter { $0.confidence > 0.2 }
        guard pts.count >= 6 else { return 0 }
        let inside = pts.filter { $0.x > 0.02 && $0.x < 0.98 && $0.y > 0.02 && $0.y < 0.98 }
        return Double(inside.count) / Double(pts.count)
    }
}

extension PoseFrame {
    private enum CodingKeys: String, CodingKey { case time, joints, aspectRatio }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let time = try container.decode(TimeInterval.self, forKey: .time)
        let joints = try container.decode([PoseJoint: PosePoint].self, forKey: .joints)
        // Frames saved before aspect correction existed decode as square.
        let aspect = try container.decodeIfPresent(Double.self, forKey: .aspectRatio) ?? 1
        self.init(time: time, joints: joints, aspectRatio: aspect)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(time, forKey: .time)
        try container.encode(joints, forKey: .joints)
        try container.encode(aspectRatio, forKey: .aspectRatio)
    }
}

nonisolated enum Handedness: String, Codable, CaseIterable, Sendable, Identifiable {
    case right, left
    nonisolated var id: String { rawValue }
    var displayName: String { self == .right ? "Right" : "Left" }
    var opposite: Handedness { self == .right ? .left : .right }
}

// MARK: - Geometry helpers

nonisolated enum PoseGeometry {
    /// Interior angle ABC in degrees.
    static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag = hypot(v1.dx, v1.dy) * hypot(v2.dx, v2.dy)
        guard mag > 0 else { return 180 }
        let cosine = max(-1, min(1, dot / mag))
        return acos(cosine) * 180 / .pi
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Path length of a polyline.
    static func pathLength(_ points: [CGPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }
}
