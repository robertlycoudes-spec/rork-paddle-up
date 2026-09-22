//
//  Mechanics.swift
//  PaddleUp
//
//  Mechanic taxonomy, per-shot rubrics (configurable weights) and benchmark
//  ranges. Benchmarks live here, apart from screen logic, so they can later be
//  replaced with values derived from coach review or elite footage.
//

import Foundation

nonisolated enum MechanicID: String, Codable, CaseIterable, Sendable, Identifiable {
    // Shipping dink mechanics
    case kneeBend
    case contactPosition
    case armStructure
    case headStability
    case followThrough
    // Architected, measured where possible
    case torsoStability
    case balance
    case paddlePosition
    case paddleFaceStability
    case shoulderMovement
    case wristMovement
    case stanceWidth
    case recoveryPosition
    case weightTransfer
    case contactHeight
    case movementConsistency
    case torsoRotation
    case armPath
    case softHands
    case setup

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kneeBend: return "Knee Bend"
        case .contactPosition: return "Contact Position"
        case .armStructure: return "Arm Structure"
        case .headStability: return "Head Stability"
        case .followThrough: return "Follow-Through"
        case .torsoStability: return "Torso Stability"
        case .balance: return "Balance"
        case .paddlePosition: return "Paddle Position"
        case .paddleFaceStability: return "Paddle-Face Stability"
        case .shoulderMovement: return "Shoulder Movement"
        case .wristMovement: return "Wrist Movement"
        case .stanceWidth: return "Stance Width"
        case .recoveryPosition: return "Recovery Position"
        case .weightTransfer: return "Weight Transfer"
        case .contactHeight: return "Contact Height"
        case .movementConsistency: return "Movement Consistency"
        case .torsoRotation: return "Torso Rotation"
        case .armPath: return "Arm Path"
        case .softHands: return "Soft Hands"
        case .setup: return "Setup"
        }
    }

    /// Short imperative cue the player hears or reads mid-session.
    var shortCue: String {
        switch self {
        case .kneeBend: return "STAY LOW"
        case .contactPosition: return "CONTACT OUT FRONT"
        case .armStructure: return "FIRM ARM SHAPE"
        case .headStability: return "HEAD STILL"
        case .followThrough: return "FINISH THE SWING"
        case .torsoStability: return "QUIET TORSO"
        case .balance: return "STAY BALANCED"
        case .paddlePosition: return "PADDLE UP"
        case .paddleFaceStability: return "STEADY FACE"
        case .shoulderMovement: return "LEAD WITH SHOULDER"
        case .wristMovement: return "QUIET WRIST"
        case .stanceWidth: return "WIDEN BASE"
        case .recoveryPosition: return "RESET YOUR FEET"
        case .weightTransfer: return "MOVE THROUGH IT"
        case .contactHeight: return "LIFT CONTACT"
        case .movementConsistency: return "SAME EVERY REP"
        case .torsoRotation: return "ROTATE THE CHEST"
        case .armPath: return "CLEAN ARM PATH"
        case .softHands: return "SOFT HANDS"
        case .setup: return "SET UP EARLY"
        }
    }
}

/// A single weighted mechanic inside a shot's rubric.
nonisolated struct RubricComponent: Codable, Sendable, Identifiable {
    let mechanic: MechanicID
    /// 0...1, weights within a rubric sum to 1.
    var weight: Double
    /// False while a mechanic is defined but not yet measurable from pose.
    var isMeasured: Bool

    nonisolated var id: String { mechanic.rawValue }
}

/// Per-shot scoring rubric. Every shot has its OWN rubric — never a single
/// generic model across shot types.
nonisolated struct ShotRubric: Codable, Sendable {
    let shot: ShotType
    var components: [RubricComponent]
    /// Bumped whenever weights or benchmarks change, so historical scores
    /// remain interpretable.
    var version: Int

    var measuredComponents: [RubricComponent] { components.filter(\.isMeasured) }

    /// Weights renormalised over the components we can actually measure today.
    var normalizedMeasuredWeights: [MechanicID: Double] {
        let measured = measuredComponents
        let total = measured.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return [:] }
        return Dictionary(uniqueKeysWithValues: measured.map { ($0.mechanic, $0.weight / total) })
    }
}

/// Registry of rubrics. Weights are configurable at runtime (developer mode).
nonisolated enum RubricLibrary {
    nonisolated(unsafe) private static var overrides: [ShotType: ShotRubric] = [:]

    static func rubric(for shot: ShotType) -> ShotRubric {
        if let override = overrides[shot] { return override }
        return defaultRubric(for: shot)
    }

    static func setWeights(_ weights: [MechanicID: Double], for shot: ShotType) {
        var rubric = rubric(for: shot)
        rubric.components = rubric.components.map { component in
            var copy = component
            if let newWeight = weights[component.mechanic] { copy.weight = newWeight }
            return copy
        }
        overrides[shot] = rubric
    }

    static func resetOverrides() { overrides.removeAll() }

    static func defaultRubric(for shot: ShotType) -> ShotRubric {
        switch shot {
        case .forehandDink, .backhandDink:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .kneeBend, weight: 0.25, isMeasured: true),
                RubricComponent(mechanic: .contactPosition, weight: 0.25, isMeasured: true),
                RubricComponent(mechanic: .armStructure, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .headStability, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .followThrough, weight: 0.15, isMeasured: true)
            ], version: 1)

        case .reset:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .balance, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .contactPosition, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .kneeBend, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .softHands, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .headStability, weight: 0.10, isMeasured: true),
                RubricComponent(mechanic: .paddleFaceStability, weight: 0.15, isMeasured: false)
            ], version: 1)

        case .thirdShotDrop:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .kneeBend, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .contactPosition, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .followThrough, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .headStability, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .weightTransfer, weight: 0.25, isMeasured: true)
            ], version: 1)

        case .serve:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .stanceWidth, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .kneeBend, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .weightTransfer, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .contactPosition, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .followThrough, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .balance, weight: 0.15, isMeasured: true)
            ], version: 1)

        case .forehandDrive, .backhandDrive:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .kneeBend, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .torsoRotation, weight: 0.25, isMeasured: false),
                RubricComponent(mechanic: .contactPosition, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .weightTransfer, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .followThrough, weight: 0.20, isMeasured: true)
            ], version: 1)

        case .forehandVolley, .backhandVolley, .block, .rollVolley:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .paddlePosition, weight: 0.25, isMeasured: false),
                RubricComponent(mechanic: .contactPosition, weight: 0.25, isMeasured: true),
                RubricComponent(mechanic: .armStructure, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .balance, weight: 0.15, isMeasured: true),
                RubricComponent(mechanic: .headStability, weight: 0.15, isMeasured: true)
            ], version: 1)

        case .returnOfServe, .speedUp, .overhead, .lob:
            return ShotRubric(shot: shot, components: [
                RubricComponent(mechanic: .setup, weight: 0.20, isMeasured: false),
                RubricComponent(mechanic: .contactPosition, weight: 0.25, isMeasured: true),
                RubricComponent(mechanic: .weightTransfer, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .followThrough, weight: 0.20, isMeasured: true),
                RubricComponent(mechanic: .balance, weight: 0.15, isMeasured: true)
            ], version: 1)
        }
    }
}

/// A measurable range for one mechanic. `ideal` scores 100; the score decays
/// through `acceptable` and bottoms out beyond it.
nonisolated struct BenchmarkRange: Codable, Sendable {
    let idealLow: Double
    let idealHigh: Double
    let acceptableLow: Double
    let acceptableHigh: Double
    let unit: String
    /// Where this range came from — never claim clinical validation.
    let source: BenchmarkSource

    func score(for value: Double) -> Double {
        if value >= idealLow && value <= idealHigh { return 100 }
        if value < idealLow {
            let span = max(0.0001, idealLow - acceptableLow)
            let t = (value - acceptableLow) / span
            return max(10, 45 + 55 * min(1, max(0, t)))
        }
        let span = max(0.0001, acceptableHigh - idealHigh)
        let t = (acceptableHigh - value) / span
        return max(10, 45 + 55 * min(1, max(0, t)))
    }
}

nonisolated enum BenchmarkSource: String, Codable, Sendable {
    /// Derived from coaching heuristics — a starting point, not validated science.
    case coachingHeuristic
    /// Set from reviewed elite footage.
    case eliteFootage
    /// Learned from aggregate Paddle Up usage.
    case aggregateUsage
}

/// Benchmark ranges, stored separately from scoring logic so they can be
/// swapped for coach-validated or data-derived values without touching code
/// that consumes them.
nonisolated enum BenchmarkLibrary {
    static let version = "v1-heuristic-2026.09"

    /// Ranges keyed by shot + mechanic. Values are expressed in the units the
    /// `MechanicsAnalyzer` produces.
    static func range(shot: ShotType, mechanic: MechanicID) -> BenchmarkRange? {
        switch (shot.group, mechanic) {
        // MARK: Dink
        case (.dink, .kneeBend):
            // Interior knee angle in degrees at contact. 180 = straight legs.
            return BenchmarkRange(idealLow: 118, idealHigh: 148, acceptableLow: 95, acceptableHigh: 172,
                                  unit: "°", source: .coachingHeuristic)
        case (.dink, .contactPosition):
            // Horizontal wrist-to-shoulder distance / shoulder width at contact.
            return BenchmarkRange(idealLow: 0.85, idealHigh: 1.55, acceptableLow: 0.25, acceptableHigh: 2.1,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.dink, .armStructure):
            // Elbow angle at contact.
            return BenchmarkRange(idealLow: 122, idealHigh: 158, acceptableLow: 85, acceptableHigh: 178,
                                  unit: "°", source: .coachingHeuristic)
        case (.dink, .headStability):
            // Head travel during the rep / shoulder width. Lower is better.
            return BenchmarkRange(idealLow: 0, idealHigh: 0.22, acceptableLow: -0.1, acceptableHigh: 0.75,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.dink, .followThrough):
            // Wrist path length after contact / shoulder width.
            return BenchmarkRange(idealLow: 0.45, idealHigh: 1.15, acceptableLow: 0.08, acceptableHigh: 1.9,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.dink, .contactHeight):
            return BenchmarkRange(idealLow: -0.15, idealHigh: 0.35, acceptableLow: -0.6, acceptableHigh: 0.85,
                                  unit: "×torso", source: .coachingHeuristic)

        // MARK: Reset
        case (.reset, .kneeBend):
            return BenchmarkRange(idealLow: 110, idealHigh: 142, acceptableLow: 90, acceptableHigh: 168,
                                  unit: "°", source: .coachingHeuristic)
        case (.reset, .contactPosition):
            return BenchmarkRange(idealLow: 0.75, idealHigh: 1.45, acceptableLow: 0.2, acceptableHigh: 2.0,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.reset, .balance):
            return BenchmarkRange(idealLow: 0, idealHigh: 0.18, acceptableLow: -0.1, acceptableHigh: 0.7,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.reset, .softHands):
            // Peak wrist speed through contact, normalised. Lower = softer.
            return BenchmarkRange(idealLow: 0, idealHigh: 1.5, acceptableLow: -0.2, acceptableHigh: 4.2,
                                  unit: "×shoulder/s", source: .coachingHeuristic)
        case (.reset, .headStability):
            return BenchmarkRange(idealLow: 0, idealHigh: 0.24, acceptableLow: -0.1, acceptableHigh: 0.8,
                                  unit: "×shoulder", source: .coachingHeuristic)

        // MARK: Third-shot drop
        case (.thirdShotDrop, .kneeBend):
            return BenchmarkRange(idealLow: 120, idealHigh: 152, acceptableLow: 95, acceptableHigh: 175,
                                  unit: "°", source: .coachingHeuristic)
        case (.thirdShotDrop, .contactPosition):
            return BenchmarkRange(idealLow: 0.9, idealHigh: 1.7, acceptableLow: 0.3, acceptableHigh: 2.3,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.thirdShotDrop, .followThrough):
            return BenchmarkRange(idealLow: 0.6, idealHigh: 1.5, acceptableLow: 0.1, acceptableHigh: 2.3,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.thirdShotDrop, .headStability):
            return BenchmarkRange(idealLow: 0, idealHigh: 0.3, acceptableLow: -0.1, acceptableHigh: 0.9,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.thirdShotDrop, .weightTransfer):
            // Forward hip travel through contact / shoulder width.
            return BenchmarkRange(idealLow: 0.12, idealHigh: 0.6, acceptableLow: -0.15, acceptableHigh: 1.1,
                                  unit: "×shoulder", source: .coachingHeuristic)

        // MARK: Serve
        case (.serve, .stanceWidth):
            return BenchmarkRange(idealLow: 0.95, idealHigh: 1.7, acceptableLow: 0.45, acceptableHigh: 2.4,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.serve, .kneeBend):
            return BenchmarkRange(idealLow: 130, idealHigh: 162, acceptableLow: 100, acceptableHigh: 178,
                                  unit: "°", source: .coachingHeuristic)
        case (.serve, .weightTransfer):
            return BenchmarkRange(idealLow: 0.2, idealHigh: 0.8, acceptableLow: -0.1, acceptableHigh: 1.4,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.serve, .contactPosition):
            return BenchmarkRange(idealLow: 0.7, idealHigh: 1.5, acceptableLow: 0.15, acceptableHigh: 2.2,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.serve, .followThrough):
            return BenchmarkRange(idealLow: 0.8, idealHigh: 1.9, acceptableLow: 0.2, acceptableHigh: 2.8,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (.serve, .balance):
            return BenchmarkRange(idealLow: 0, idealHigh: 0.22, acceptableLow: -0.1, acceptableHigh: 0.8,
                                  unit: "×shoulder", source: .coachingHeuristic)

        // MARK: Generic fallbacks for preview-quality shots
        case (_, .kneeBend):
            return BenchmarkRange(idealLow: 120, idealHigh: 155, acceptableLow: 95, acceptableHigh: 178,
                                  unit: "°", source: .coachingHeuristic)
        case (_, .contactPosition):
            return BenchmarkRange(idealLow: 0.8, idealHigh: 1.6, acceptableLow: 0.2, acceptableHigh: 2.2,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (_, .armStructure):
            return BenchmarkRange(idealLow: 120, idealHigh: 160, acceptableLow: 85, acceptableHigh: 178,
                                  unit: "°", source: .coachingHeuristic)
        case (_, .headStability):
            return BenchmarkRange(idealLow: 0, idealHigh: 0.26, acceptableLow: -0.1, acceptableHigh: 0.85,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (_, .followThrough):
            return BenchmarkRange(idealLow: 0.5, idealHigh: 1.4, acceptableLow: 0.08, acceptableHigh: 2.3,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (_, .balance):
            return BenchmarkRange(idealLow: 0, idealHigh: 0.2, acceptableLow: -0.1, acceptableHigh: 0.8,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (_, .weightTransfer):
            return BenchmarkRange(idealLow: 0.1, idealHigh: 0.7, acceptableLow: -0.2, acceptableHigh: 1.3,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (_, .stanceWidth):
            return BenchmarkRange(idealLow: 0.9, idealHigh: 1.8, acceptableLow: 0.4, acceptableHigh: 2.5,
                                  unit: "×shoulder", source: .coachingHeuristic)
        case (_, .softHands):
            return BenchmarkRange(idealLow: 0, idealHigh: 1.8, acceptableLow: -0.2, acceptableHigh: 4.5,
                                  unit: "×shoulder/s", source: .coachingHeuristic)
        case (_, .contactHeight):
            return BenchmarkRange(idealLow: -0.15, idealHigh: 0.4, acceptableLow: -0.7, acceptableHigh: 1.0,
                                  unit: "×torso", source: .coachingHeuristic)
        default:
            return nil
        }
    }
}
