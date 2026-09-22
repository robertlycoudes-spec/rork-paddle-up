//
//  ScoringEngine.swift
//  PaddleUp
//
//  Converts normalised measurements into 1-100 mechanic scores and a weighted
//  Paddle Up score, using the shot's own rubric and benchmark ranges.
//

import Foundation

nonisolated struct RepAnalysis: Sendable {
    let shot: ShotType
    /// 1...100.
    let score: Double
    let mechanics: [MechanicScore]
    let dominantIssue: MechanicID?
    /// True when the dominant mechanic's raw value sat above the ideal band.
    let dominantValueIsHigh: Bool
    let confidence: Double
    let rubricVersion: Int
}

nonisolated enum ScoringEngine {

    /// Score one detected rep. Each shot uses its own rubric — never a single
    /// generic model.
    static func score(measurements: [MechanicMeasurement], shot: ShotType,
                      detectionConfidence: Double) -> RepAnalysis {
        let rubric = RubricLibrary.rubric(for: shot)
        let weights = rubric.normalizedMeasuredWeights

        var mechanicScores: [MechanicScore] = []
        var highFlags: [MechanicID: Bool] = [:]

        for measurement in measurements {
            guard let range = BenchmarkLibrary.range(shot: shot, mechanic: measurement.mechanic) else { continue }
            let raw = range.score(for: measurement.value)
            mechanicScores.append(MechanicScore(
                mechanic: measurement.mechanic,
                score: clamp(raw),
                rawValue: measurement.value,
                unit: measurement.unit,
                confidence: measurement.confidence
            ))
            highFlags[measurement.mechanic] = measurement.value > range.idealHigh
        }

        // Keep rubric order so the breakdown always reads the same way.
        let ordered = rubric.components.compactMap { component in
            mechanicScores.first { $0.mechanic == component.mechanic }
        }

        var weightedTotal: Double = 0
        var weightUsed: Double = 0
        for mechanic in ordered {
            guard let weight = weights[mechanic.mechanic] else { continue }
            weightedTotal += mechanic.score * weight
            weightUsed += weight
        }

        let base = weightUsed > 0 ? weightedTotal / weightUsed : 0
        // Low-confidence measurement pulls the score gently toward the middle
        // rather than producing a confidently wrong extreme.
        let blended = base * detectionConfidence + 70 * (1 - detectionConfidence) * 0.35
            + base * (1 - detectionConfidence) * 0.65

        // The dominant issue is the weakest mechanic weighted by how much it
        // matters in this rubric — a small miss on a 25% mechanic outranks a
        // large miss on a 10% one.
        let dominant = ordered
            .filter { $0.score < 82 }
            .max { lhs, rhs in
                let lw = weights[lhs.mechanic] ?? 0
                let rw = weights[rhs.mechanic] ?? 0
                return (100 - lhs.score) * lw < (100 - rhs.score) * rw
            }

        return RepAnalysis(
            shot: shot,
            score: clamp(blended.rounded()),
            mechanics: ordered,
            dominantIssue: dominant?.mechanic,
            dominantValueIsHigh: dominant.map { highFlags[$0.mechanic] ?? false } ?? false,
            confidence: detectionConfidence,
            rubricVersion: rubric.version
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(100, max(1, value))
    }

    /// Roll per-rep scores up into a shot-group rating (1-100), weighting
    /// recent reps more heavily so the rating tracks current form.
    static func rating(from reps: [RepRecord]) -> Double? {
        guard !reps.isEmpty else { return nil }
        let sorted = reps.sorted { $0.timestamp < $1.timestamp }
        var weightedSum: Double = 0
        var weightTotal: Double = 0
        for (index, rep) in sorted.enumerated() {
            let recency = Double(index + 1) / Double(sorted.count)
            let weight = 0.35 + recency * 0.65
            weightedSum += rep.score * weight
            weightTotal += weight
        }
        guard weightTotal > 0 else { return nil }
        return min(100, max(1, weightedSum / weightTotal))
    }

    /// Overall Paddle Up Rating derived from per-shot ratings. Shots with more
    /// evidence count more; this is explicitly NOT a DUPR rating.
    static func overallRating(from ratings: [ShotRating]) -> Double? {
        let rated = ratings.filter { $0.repCount > 0 }
        guard !rated.isEmpty else { return nil }
        var weightedSum: Double = 0
        var weightTotal: Double = 0
        for rating in rated {
            let evidence = min(1.0, Double(rating.repCount) / 60.0)
            let weight = 0.4 + evidence * 0.6
            weightedSum += rating.score * weight
            weightTotal += weight
        }
        return min(100, max(1, weightedSum / weightTotal))
    }
}
