//
//  PoseSmoother.swift
//  PaddleUp
//
//  Per-joint One Euro filtering. Raw Vision joints jitter by a few pixels even
//  when the player stands still; at 15 fps that jitter differentiates into
//  fake wrist speed, which stops the rep detector from ever settling and adds
//  noise to every angle. The One Euro filter smooths heavily at rest and
//  barely at all during a fast swing, so real peaks survive.
//

import Foundation

nonisolated struct OneEuroFilter {
    let minCutoff: Double
    let beta: Double
    let derivativeCutoff: Double

    private var value: Double?
    private var derivative: Double = 0
    private var lastTime: TimeInterval = 0

    init(minCutoff: Double, beta: Double, derivativeCutoff: Double) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    mutating func filter(_ raw: Double, at time: TimeInterval) -> Double {
        guard let previous = value, time > lastTime else {
            value = raw
            derivative = 0
            lastTime = time
            return raw
        }
        let elapsed = time - lastTime
        let rawDerivative = (raw - previous) / elapsed
        derivative += Self.alpha(cutoff: derivativeCutoff, elapsed: elapsed) * (rawDerivative - derivative)
        let cutoff = minCutoff + beta * abs(derivative)
        let smoothed = previous + Self.alpha(cutoff: cutoff, elapsed: elapsed) * (raw - previous)
        value = smoothed
        lastTime = time
        return smoothed
    }

    static func alpha(cutoff: Double, elapsed: TimeInterval) -> Double {
        let tau = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + tau / elapsed)
    }
}

nonisolated struct PoseSmoother {
    /// Rest cutoff (Hz): lower = steadier when still.
    var minCutoff: Double = 2.0
    /// Speed responsiveness in normalised-units/s: higher = less lag in swings.
    var beta: Double = 15
    var derivativeCutoff: Double = 1.0
    /// A joint unseen for longer than this restarts its filter.
    var jointTimeout: TimeInterval = 0.5

    private var filters: [PoseJoint: (x: OneEuroFilter, y: OneEuroFilter, seen: TimeInterval)] = [:]

    mutating func reset() { filters.removeAll() }

    mutating func smooth(_ frame: PoseFrame) -> PoseFrame {
        var joints: [PoseJoint: PosePoint] = [:]
        for (joint, point) in frame.joints {
            var entry = filters[joint]
            if entry == nil || frame.time - (entry?.seen ?? 0) > jointTimeout {
                entry = (OneEuroFilter(minCutoff: minCutoff, beta: beta, derivativeCutoff: derivativeCutoff),
                         OneEuroFilter(minCutoff: minCutoff, beta: beta, derivativeCutoff: derivativeCutoff),
                         frame.time)
            }
            guard var current = entry else { continue }
            let x = current.x.filter(point.x, at: frame.time)
            let y = current.y.filter(point.y, at: frame.time)
            current.seen = frame.time
            filters[joint] = current
            joints[joint] = PosePoint(x: x, y: y, confidence: point.confidence)
        }
        return PoseFrame(time: frame.time, joints: joints, aspectRatio: frame.aspectRatio)
    }
}
