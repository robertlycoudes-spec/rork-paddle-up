//
//  ScoringEngineTests.swift
//  PaddleUpTests
//
//  ScoringEngine maths against hand-computed expectations. Dink rubric:
//  knee bend 25%, contact 25%, arm 20%, head 15%, follow-through 15%.
//

import Foundation
import Testing
@testable import PaddleUp

private func measurement(_ mechanic: MechanicID, _ value: Double) -> MechanicMeasurement {
    MechanicMeasurement(mechanic: mechanic, value: value, unit: "", confidence: 1)
}

/// Mid-ideal value for each dink mechanic.
private let idealDink: [MechanicMeasurement] = [
    measurement(.kneeBend, 130),
    measurement(.contactPosition, 1.2),
    measurement(.armStructure, 140),
    measurement(.headStability, 0.1),
    measurement(.followThrough, 0.8)
]

private func replacing(_ mechanic: MechanicID, with value: Double) -> [MechanicMeasurement] {
    idealDink.map { $0.mechanic == mechanic ? measurement(mechanic, value) : $0 }
}

struct ScoringEngineRepTests {

    @Test func perfectDinkScores100WithNoDominantIssue() {
        let analysis = ScoringEngine.score(measurements: idealDink, shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.score == 100)
        #expect(analysis.dominantIssue == nil)
        #expect(analysis.mechanics.allSatisfy { $0.score == 100 })
        #expect(analysis.rubricVersion == 1)
    }

    @Test func weightedTotalMatchesHandCalculation() {
        // Knee bend at the acceptable edge (172°) scores 45.
        // 45 × 0.25 + 100 × 0.75 = 86.25 → 86.
        let analysis = ScoringEngine.score(measurements: replacing(.kneeBend, with: 172),
                                           shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.mechanic(.kneeBend)?.score == 45)
        #expect(analysis.score == 86)
        #expect(analysis.dominantIssue == .kneeBend)
        #expect(analysis.dominantValueIsHigh)
    }

    @Test func lowValueFlagsDominantIssueAsLow() {
        // Contact 0.25 × shoulder (acceptable low) scores 45 → 86 overall.
        let analysis = ScoringEngine.score(measurements: replacing(.contactPosition, with: 0.25),
                                           shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.score == 86)
        #expect(analysis.dominantIssue == .contactPosition)
        #expect(!analysis.dominantValueIsHigh)
    }

    @Test func lowConfidenceBlendsTowardTheMiddle() {
        // 100 × 0.5 + 70 × 0.5 × 0.35 + 100 × 0.5 × 0.65 = 94.75 → 95.
        let analysis = ScoringEngine.score(measurements: idealDink, shot: .forehandDink, detectionConfidence: 0.5)
        #expect(analysis.score == 95)
        #expect(analysis.confidence == 0.5)
    }

    @Test func dominantIssueWeighsMissByRubricWeight() {
        // Equal 45-point scores: knee bend (25%) outranks head stability (15%).
        var measurements = replacing(.kneeBend, with: 172)
        measurements = measurements.map { $0.mechanic == .headStability ? measurement(.headStability, 0.75) : $0 }
        let analysis = ScoringEngine.score(measurements: measurements, shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.mechanic(.headStability)?.score == 45)
        #expect(analysis.dominantIssue == .kneeBend)
        // 45 × 0.25 + 45 × 0.15 + 100 × 0.60 = 78.
        #expect(analysis.score == 78)
    }

    @Test func minorMissesAbove82AreNotFlagged() {
        // Knee bend 160°: t = (172 − 160) / 24 = 0.5 → 45 + 27.5 = 72.5 is flagged,
        // but 166°: t = 0.25 → 58.75 is also flagged; 150° → t ≈ 0.917 → 95.4 is not.
        let analysis = ScoringEngine.score(measurements: replacing(.kneeBend, with: 150),
                                           shot: .forehandDink, detectionConfidence: 1)
        let knee = analysis.mechanic(.kneeBend)?.score ?? 0
        #expect(abs(knee - (45 + 55 * (22.0 / 24.0))) < 0.0001)
        #expect(analysis.dominantIssue == nil)
    }

    @Test func mechanicsAreReturnedInRubricOrder() {
        let shuffled = Array(idealDink.reversed())
        let analysis = ScoringEngine.score(measurements: shuffled, shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.mechanics.map(\.mechanic) == [.kneeBend, .contactPosition, .armStructure, .headStability, .followThrough])
    }

    @Test func mechanicsWithoutABenchmarkAreIgnored() {
        let analysis = ScoringEngine.score(measurements: idealDink + [measurement(.paddlePosition, 999)],
                                           shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.mechanic(.paddlePosition) == nil)
        #expect(analysis.score == 100)
    }

    @Test func partialMeasurementsRenormaliseWeights() {
        // Only knee (45) and contact (100) measured, equal 25% weights → 72.5 → 73 (rounded half away from zero).
        let analysis = ScoringEngine.score(measurements: [measurement(.kneeBend, 172), measurement(.contactPosition, 1.2)],
                                           shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.score == 73)
    }

    @Test func noMeasurementsClampToTheFloor() {
        let analysis = ScoringEngine.score(measurements: [], shot: .forehandDink, detectionConfidence: 1)
        #expect(analysis.score == 1)
        #expect(analysis.mechanics.isEmpty)
    }
}

private extension RepAnalysis {
    func mechanic(_ id: MechanicID) -> MechanicScore? { mechanics.first { $0.mechanic == id } }
}

struct ScoringEngineRatingTests {

    private func rep(score: Double, at seconds: TimeInterval) -> RepRecord {
        RepRecord(sessionID: UUID(), index: 1, timestamp: Date(timeIntervalSince1970: seconds),
                  shot: .forehandDink, score: score, mechanics: [], correction: "", nextRepCue: "",
                  confidence: 1)
    }

    @Test func emptyRepsHaveNoRating() {
        #expect(ScoringEngine.rating(from: []) == nil)
    }

    @Test func singleRepRatingIsItsScore() {
        #expect(ScoringEngine.rating(from: [rep(score: 64, at: 0)]) == 64)
    }

    @Test func recentRepsWeighMore() throws {
        // Weights: older 0.35 + 0.5 × 0.65 = 0.675, newer 1.0.
        // (50 × 0.675 + 100) / 1.675 = 79.8507…
        let rating = try #require(ScoringEngine.rating(from: [rep(score: 100, at: 10), rep(score: 50, at: 0)]))
        #expect(abs(rating - 133.75 / 1.675) < 0.0001)
    }

    @Test func overallRatingWeighsByEvidence() throws {
        // 60 reps → weight 1.0; 0 reps excluded; 6 reps → 0.4 + 0.1 × 0.6 = 0.46.
        let ratings = [
            ShotRating(group: .dink, score: 80, previousScore: nil, repCount: 60),
            ShotRating(group: .serve, score: 40, previousScore: nil, repCount: 6),
            ShotRating(group: .drive, score: 10, previousScore: nil, repCount: 0)
        ]
        let overall = try #require(ScoringEngine.overallRating(from: ratings))
        #expect(abs(overall - (80 * 1.0 + 40 * 0.46) / 1.46) < 0.0001)
    }
}
