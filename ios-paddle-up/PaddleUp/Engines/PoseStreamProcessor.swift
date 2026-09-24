//
//  PoseStreamProcessor.swift
//  PaddleUp
//
//  Turns per-frame Vision detections into one clean, time-ordered pose stream
//  for a single player:
//
//    candidates → PlayerTracker (same person) → PoseSmoother (no jitter)
//
//  Live camera sessions and uploaded videos both use this, so the rep
//  detector sees identical input quality from either source.
//

import Foundation

nonisolated final class PoseStreamProcessor {
    private var tracker = PlayerTracker()
    private var smoother = PoseSmoother()
    private var lastTime: TimeInterval = -.infinity

    init() {}

    func reset() {
        tracker.reset()
        smoother.reset()
        lastTime = -.infinity
    }

    /// Returns the tracked player's smoothed pose, or nil if they aren't
    /// visible in this frame. Frames must arrive in time order; stale or
    /// duplicate timestamps are dropped.
    func process(candidates: [PoseFrame], at time: TimeInterval) -> PoseFrame? {
        guard time > lastTime else { return nil }
        lastTime = time
        guard let selection = tracker.select(from: candidates, at: time) else { return nil }
        if selection.isNewLock { smoother.reset() }
        return smoother.smooth(selection.frame)
    }
}
