//
//  ReferenceMatcher.swift
//  PaddleUp
//
//  Swing Match: compares a player's normalised mechanics against elite
//  reference profiles and returns a similarity percentage.
//
//  LICENSING: references are anonymised archetypes ("Elite Reference A"), NOT
//  real professionals. `ReferenceProfile` is intentionally shaped so licensed
//  pro data can be dropped in later without touching the matching maths.
//

import Foundation

/// A reference swing profile: the normalised mechanic values an archetype
/// produces at contact. Comparison is on MOVEMENT, never appearance.
nonisolated struct ReferenceProfile: Codable, Sendable, Identifiable {
    let id: String
    let displayName: String
    /// Short characterisation of the playing style.
    let styleDescriptor: String
    let shot: ShotType
    /// Normalised mechanic values, in the same units the analyzer produces.
    let signature: [MechanicID: Double]
    /// Swing tempo in seconds from forward-swing start to follow-through end.
    let tempo: Double
    /// Set true once a licensed athlete's data backs this profile.
    let isLicensedAthlete: Bool

    var avatarSymbol: String {
        switch styleDescriptor {
        case let s where s.contains("Control"): return "target"
        case let s where s.contains("Power"): return "bolt.fill"
        default: return "figure.pickleball"
        }
    }
}

nonisolated struct SwingMatchResult: Sendable, Identifiable {
    let id = UUID()
    let profile: ReferenceProfile
    /// 0...100.
    let similarity: Double
    /// Per-mechanic comparison: your value vs the reference's.
    let comparisons: [MechanicComparison]

    var closestDifference: MechanicComparison? {
        comparisons.max { abs($0.normalizedGap) < abs($1.normalizedGap) }
    }
}

nonisolated struct MechanicComparison: Sendable, Identifiable {
    let mechanic: MechanicID
    let yourValue: Double
    let referenceValue: Double
    let unit: String
    /// Gap expressed in the mechanic's own units (signed).
    var difference: Double { yourValue - referenceValue }
    /// Gap scaled by a sensible range for the mechanic, for ranking.
    let normalizedGap: Double
    let meaning: String

    nonisolated var id: String { mechanic.rawValue }

    var formattedDifference: String {
        let sign = difference >= 0 ? "+" : ""
        if unit == "°" { return "\(sign)\(Int(difference.rounded()))\(unit)" }
        return String(format: "%@%.2f", sign, difference)
    }

    func formatted(_ value: Double) -> String {
        unit == "°" ? "\(Int(value.rounded()))°" : String(format: "%.2f", value)
    }
}

nonisolated enum ReferenceLibrary {
    static let profiles: [ReferenceProfile] = [
        ReferenceProfile(
            id: "elite_a",
            displayName: "Elite Reference A",
            styleDescriptor: "Control specialist",
            shot: .forehandDink,
            signature: [
                .kneeBend: 133,
                .contactPosition: 1.32,
                .armStructure: 141,
                .headStability: 0.12,
                .followThrough: 0.78
            ],
            tempo: 0.62,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "elite_b",
            displayName: "Elite Reference B",
            styleDescriptor: "Aggressive kitchen attacker",
            shot: .forehandDink,
            signature: [
                .kneeBend: 126,
                .contactPosition: 1.48,
                .armStructure: 133,
                .headStability: 0.17,
                .followThrough: 1.02
            ],
            tempo: 0.54,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "coach_reference",
            displayName: "Coach Reference",
            styleDescriptor: "Textbook fundamentals",
            shot: .forehandDink,
            signature: [
                .kneeBend: 138,
                .contactPosition: 1.18,
                .armStructure: 146,
                .headStability: 0.09,
                .followThrough: 0.70
            ],
            tempo: 0.68,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "elite_a_backhand",
            displayName: "Elite Reference A",
            styleDescriptor: "Control specialist",
            shot: .backhandDink,
            signature: [
                .kneeBend: 130,
                .contactPosition: 1.22,
                .armStructure: 137,
                .headStability: 0.13,
                .followThrough: 0.74
            ],
            tempo: 0.60,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "advanced_benchmark_backhand",
            displayName: "Advanced Benchmark",
            styleDescriptor: "Steady club-level advanced",
            shot: .backhandDink,
            signature: [
                .kneeBend: 142,
                .contactPosition: 1.05,
                .armStructure: 148,
                .headStability: 0.2,
                .followThrough: 0.62
            ],
            tempo: 0.66,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "elite_c_reset",
            displayName: "Elite Reference C",
            styleDescriptor: "Defensive reset master",
            shot: .reset,
            signature: [
                .kneeBend: 124,
                .contactPosition: 1.1,
                .balance: 0.1,
                .softHands: 0.9,
                .headStability: 0.12
            ],
            tempo: 0.5,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "elite_d_drop",
            displayName: "Elite Reference D",
            styleDescriptor: "Patient drop builder",
            shot: .thirdShotDrop,
            signature: [
                .kneeBend: 134,
                .contactPosition: 1.35,
                .followThrough: 1.1,
                .headStability: 0.16,
                .weightTransfer: 0.38
            ],
            tempo: 0.72,
            isLicensedAthlete: false
        ),
        ReferenceProfile(
            id: "elite_e_serve",
            displayName: "Elite Reference E",
            styleDescriptor: "Repeatable power server",
            shot: .serve,
            signature: [
                .stanceWidth: 1.35,
                .kneeBend: 148,
                .weightTransfer: 0.52,
                .contactPosition: 1.1,
                .followThrough: 1.4,
                .balance: 0.14
            ],
            tempo: 0.8,
            isLicensedAthlete: false
        )
    ]

    static func profiles(for shot: ShotType) -> [ReferenceProfile] {
        let exact = profiles.filter { $0.shot == shot }
        if !exact.isEmpty { return exact }
        return profiles.filter { $0.shot.group == shot.group }
    }
}

nonisolated enum ReferenceMatcher {

    /// Compare a set of reps to every reference for the shot, best match first.
    static func match(reps: [RepRecord], shot: ShotType) -> [SwingMatchResult] {
        let usable = reps.filter { !$0.isDeleted && $0.shot == shot && $0.confidence > 0.35 }
        guard usable.count >= 3 else { return [] }

        // Median raw value per mechanic is robust against a few bad reps.
        var playerSignature: [MechanicID: Double] = [:]
        var units: [MechanicID: String] = [:]
        var grouped: [MechanicID: [Double]] = [:]

        for rep in usable {
            for mechanic in rep.mechanics {
                grouped[mechanic.mechanic, default: []].append(mechanic.rawValue)
                units[mechanic.mechanic] = mechanic.unit
            }
        }
        for (mechanic, values) in grouped {
            let sorted = values.sorted()
            playerSignature[mechanic] = sorted[sorted.count / 2]
        }

        return ReferenceLibrary.profiles(for: shot).map { profile in
            compare(playerSignature: playerSignature, units: units, to: profile)
        }
        .sorted { $0.similarity > $1.similarity }
    }

    private static func compare(playerSignature: [MechanicID: Double],
                                units: [MechanicID: String],
                                to profile: ReferenceProfile) -> SwingMatchResult {
        var comparisons: [MechanicComparison] = []
        var gapTotal: Double = 0
        var count: Double = 0

        for (mechanic, referenceValue) in profile.signature {
            guard let yourValue = playerSignature[mechanic] else { continue }
            let span = comparisonSpan(for: mechanic)
            let gap = (yourValue - referenceValue) / span
            gapTotal += min(1, abs(gap))
            count += 1

            comparisons.append(MechanicComparison(
                mechanic: mechanic,
                yourValue: yourValue,
                referenceValue: referenceValue,
                unit: units[mechanic] ?? "",
                normalizedGap: gap,
                meaning: meaning(for: mechanic, gap: yourValue - referenceValue,
                                 unit: units[mechanic] ?? "")
            ))
        }

        let similarity = count > 0 ? max(0, min(100, (1 - gapTotal / count) * 100)) : 0
        let ordered = comparisons.sorted { abs($0.normalizedGap) > abs($1.normalizedGap) }
        return SwingMatchResult(profile: profile, similarity: similarity, comparisons: ordered)
    }

    /// The gap size that counts as "completely different" for a mechanic.
    private static func comparisonSpan(for mechanic: MechanicID) -> Double {
        switch mechanic {
        case .kneeBend, .armStructure: return 45
        case .contactPosition, .followThrough, .stanceWidth, .weightTransfer: return 0.9
        case .headStability, .balance, .torsoStability: return 0.5
        case .softHands: return 2.5
        default: return 1.0
        }
    }

    /// Plain-language reading of what a gap against the reference means.
    private static func meaning(for mechanic: MechanicID, gap: Double, unit: String) -> String {
        let magnitude = abs(gap)
        switch mechanic {
        case .kneeBend:
            if magnitude < 6 { return "Your leg load is essentially identical." }
            return gap > 0
                ? "Your legs are \(Int(magnitude))° straighter — you are playing taller than the reference."
                : "You sit \(Int(magnitude))° deeper, which costs you mobility between balls."
        case .contactPosition:
            if magnitude < 0.12 { return "You meet the ball in the same place." }
            return gap > 0
                ? "You contact the ball farther from your body — more reach, less control."
                : "You let the ball get closer to your body before contact."
        case .armStructure:
            if magnitude < 6 { return "Your arm shape matches closely." }
            return gap > 0
                ? "Your arm is \(Int(magnitude))° straighter through contact."
                : "Your elbow is \(Int(magnitude))° more folded than the reference."
        case .headStability:
            if magnitude < 0.05 { return "Your head is just as quiet." }
            return gap > 0
                ? "Your head travels more during the swing."
                : "Your head is even quieter than the reference."
        case .followThrough:
            if magnitude < 0.12 { return "Your finish length matches." }
            return gap > 0 ? "You finish longer through the ball." : "You cut the finish shorter."
        case .weightTransfer:
            return gap > 0 ? "You move farther through contact." : "You transfer less weight forward."
        case .softHands:
            return gap > 0 ? "Your hands are firmer through contact." : "Your hands are softer than the reference."
        case .balance:
            return gap > 0 ? "Your base moves more during the shot." : "Your base is steadier."
        case .stanceWidth:
            return gap > 0 ? "You set a wider base." : "You set a narrower base."
        default:
            return "Difference of \(String(format: "%.2f", gap)) \(unit)."
        }
    }
}
