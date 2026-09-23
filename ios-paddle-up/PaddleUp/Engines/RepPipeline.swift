//
//  RepPipeline.swift
//  PaddleUp
//
//  The per-rep analysis chain shared by live sessions and uploaded videos:
//
//    RepWindow → ShotClassifier → MechanicsAnalyzer → ScoringEngine → CoachingEngine
//
//  Keeping one implementation guarantees an uploaded video is scored exactly
//  like the same swings would be scored live.
//

import Foundation

nonisolated enum RepPipeline {

    struct Scored: Sendable {
        let rep: RepRecord
        let coaching: RepCoaching
    }

    struct Outcome: Sendable {
        /// Classifier confidence, reported even when the rep couldn't be measured.
        let classificationConfidence: Double
        /// Nil when no mechanic could be measured from the window.
        let scored: Scored?
    }

    static func process(window: RepWindow, expected shot: ShotType, hand: Handedness,
                        sessionID: UUID, index: Int, timestamp: Date) -> Outcome {
        let classification = ShotClassifier.classify(window: window, hand: hand, expected: shot)

        let measurements = MechanicsAnalyzer.measure(window: window, shot: classification.shot, hand: hand)
        guard !measurements.isEmpty else {
            return Outcome(classificationConfidence: classification.confidence, scored: nil)
        }

        let combinedConfidence = window.detectionConfidence * (0.7 + 0.3 * classification.confidence)
        let analysis = ScoringEngine.score(measurements: measurements, shot: classification.shot,
                                           detectionConfidence: combinedConfidence)
        let coaching = CoachingEngine.coach(analysis: analysis)

        let rep = RepRecord(
            sessionID: sessionID,
            index: index,
            timestamp: timestamp,
            shot: classification.shot,
            score: analysis.score,
            mechanics: analysis.mechanics,
            dominantIssue: analysis.dominantIssue,
            issueID: coaching.issue?.id,
            correction: coaching.correction,
            nextRepCue: coaching.cue,
            recommendedDrillID: coaching.drillID,
            confidence: analysis.confidence,
            poseFrames: downsample(window.frames),
            rubricVersion: analysis.rubricVersion
        )
        return Outcome(classificationConfidence: classification.confidence,
                       scored: Scored(rep: rep, coaching: coaching))
    }

    /// Keep at most ~24 pose frames per rep for replay/Swing Match, so stored
    /// sessions stay small.
    static func downsample(_ frames: [PoseFrame]) -> [PoseFrame] {
        guard frames.count > 24 else { return frames }
        let stride = Double(frames.count) / 24
        return (0..<24).compactMap { frames[safe: Int(Double($0) * stride)] }
    }
}
