//
//  DinkBenchmarkTests.swift
//  PaddleUpTests
//
//  Locks the shipping dink benchmark ranges (v1-heuristic-2026.09) and the
//  shape of the range scoring curve, so a change to either is deliberate.
//

import Foundation
import Testing
@testable import PaddleUp

struct DinkBenchmarkTests {

    /// (mechanic, idealLow, idealHigh, acceptableLow, acceptableHigh, unit)
    static let expected: [(MechanicID, Double, Double, Double, Double, String)] = [
        (.kneeBend, 118, 148, 95, 172, "°"),
        (.contactPosition, 0.85, 1.55, 0.25, 2.1, "×shoulder"),
        (.armStructure, 122, 158, 85, 178, "°"),
        (.headStability, 0, 0.22, -0.1, 0.75, "×shoulder"),
        (.followThrough, 0.45, 1.15, 0.08, 1.9, "×shoulder"),
        (.contactHeight, -0.15, 0.35, -0.6, 0.85, "×torso")
    ]

    @Test func benchmarkVersionIsPinned() {
        #expect(BenchmarkLibrary.version == "v1-heuristic-2026.09")
    }

    @Test(arguments: [ShotType.forehandDink, .backhandDink])
    func dinkRangesMatchTheShippingValues(shot: ShotType) throws {
        for (mechanic, idealLow, idealHigh, acceptableLow, acceptableHigh, unit) in Self.expected {
            let range = try #require(BenchmarkLibrary.range(shot: shot, mechanic: mechanic),
                                     "Missing \(mechanic) range for \(shot)")
            #expect(range.idealLow == idealLow, "\(mechanic) idealLow")
            #expect(range.idealHigh == idealHigh, "\(mechanic) idealHigh")
            #expect(range.acceptableLow == acceptableLow, "\(mechanic) acceptableLow")
            #expect(range.acceptableHigh == acceptableHigh, "\(mechanic) acceptableHigh")
            #expect(range.unit == unit, "\(mechanic) unit")
            #expect(range.source == .coachingHeuristic, "\(mechanic) must not claim validation")
        }
    }

    @Test func everyIdealBandSitsInsideItsAcceptableBand() throws {
        for (mechanic, _, _, _, _, _) in Self.expected {
            let range = try #require(BenchmarkLibrary.range(shot: .forehandDink, mechanic: mechanic))
            #expect(range.acceptableLow < range.idealLow)
            #expect(range.idealLow < range.idealHigh)
            #expect(range.idealHigh < range.acceptableHigh)
        }
    }

    @Test func everyMeasuredDinkRubricMechanicHasABenchmark() {
        for component in RubricLibrary.defaultRubric(for: .forehandDink).measuredComponents {
            #expect(BenchmarkLibrary.range(shot: .forehandDink, mechanic: component.mechanic) != nil,
                    "\(component.mechanic) is scored but has no benchmark")
        }
    }

    @Test func dinkRubricWeightsSumToOne() {
        let total = RubricLibrary.defaultRubric(for: .forehandDink).components.reduce(0) { $0 + $1.weight }
        #expect(abs(total - 1) < 0.0001)
    }

    @Test func kneeBendScoringCurve() throws {
        let range = try #require(BenchmarkLibrary.range(shot: .forehandDink, mechanic: .kneeBend))
        // Anywhere inside the ideal band is a perfect 100, edges included.
        #expect(range.score(for: 118) == 100)
        #expect(range.score(for: 133) == 100)
        #expect(range.score(for: 148) == 100)
        // Acceptable edges score 45; halfway between scores 72.5.
        #expect(range.score(for: 95) == 45)
        #expect(range.score(for: 172) == 45)
        #expect(abs(range.score(for: 106.5) - 72.5) < 0.0001)
        #expect(abs(range.score(for: 160) - 72.5) < 0.0001)
        // Beyond acceptable the score floors at 45 rather than collapsing.
        #expect(range.score(for: 60) == 45)
        #expect(range.score(for: 180) == 45)
    }

    @Test func scoreFallsMonotonicallyAwayFromIdeal() throws {
        let range = try #require(BenchmarkLibrary.range(shot: .forehandDink, mechanic: .contactPosition))
        let outward = stride(from: 1.55, through: 2.3, by: 0.05).map(range.score(for:))
        let inward = stride(from: 0.85, through: 0.0, by: -0.05).map(range.score(for:))
        for series in [outward, inward] {
            for (earlier, later) in zip(series, series.dropFirst()) {
                #expect(later <= earlier + 0.0001)
            }
        }
    }

    @Test func headStabilityRewardsStillness() throws {
        let range = try #require(BenchmarkLibrary.range(shot: .forehandDink, mechanic: .headStability))
        #expect(range.score(for: 0) == 100)
        #expect(range.score(for: 0.22) == 100)
        #expect(range.score(for: 0.5) < 100)
        #expect(range.score(for: 0.75) == 45)
    }
}
