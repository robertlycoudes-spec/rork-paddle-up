//
//  PlayerTracker.swift
//  PaddleUp
//
//  Courts are busy. Vision returns every person in the frame in no particular
//  order, and hopping between them creates phantom "swings" and mixes two
//  people's mechanics into one rep. The tracker locks onto the most prominent
//  player and then follows that same body frame to frame.
//

import CoreGraphics
import Foundation

nonisolated struct PlayerTracker {
    /// After this long without seeing the tracked player, re-acquire.
    var maxGap: TimeInterval = 1.0
    /// Largest plausible jump between frames, in the player's own heights.
    var maxJump: Double = 0.6
    /// Minimum confident joints for a detection to count as a person.
    var minJoints: Int = 5

    private var lastCenter: CGPoint?
    private var lastHeight: Double = 0
    private var lastSeen: TimeInterval = -.infinity

    struct Selection {
        let frame: PoseFrame
        /// True when the tracker (re)acquired a player instead of continuing one.
        let isNewLock: Bool
    }

    mutating func reset() {
        lastCenter = nil
        lastHeight = 0
        lastSeen = -.infinity
    }

    mutating func select(from candidates: [PoseFrame], at time: TimeInterval) -> Selection? {
        let usable = candidates.filter { frame in
            frame.bodyCenter != nil
                && frame.joints.values.filter { $0.confidence > 0.2 }.count >= minJoints
        }
        guard !usable.isEmpty else { return nil }

        var chosen: PoseFrame?
        var isNewLock = false
        if let last = lastCenter, time - lastSeen <= maxGap {
            let reach = max(0.08, lastHeight) * maxJump
            chosen = usable
                .compactMap { frame -> (PoseFrame, Double)? in
                    guard let center = frame.bodyCenter else { return nil }
                    return (frame, hypot(center.x - last.x, center.y - last.y))
                }
                .filter { $0.1 <= reach }
                .min { $0.1 < $1.1 }?.0
        } else {
            chosen = usable.max { Self.prominence($0) < Self.prominence($1) }
            isNewLock = true
        }

        guard let chosen, let center = chosen.bodyCenter else { return nil }
        lastCenter = center
        lastHeight = chosen.apparentHeight
        lastSeen = time
        return Selection(frame: chosen, isNewLock: isNewLock)
    }

    /// Bigger and more confidently tracked = more likely the filmed player.
    static func prominence(_ frame: PoseFrame) -> Double {
        frame.apparentHeight * max(0.1, frame.meanConfidence)
    }
}
