//
//  ShotType.swift
//  PaddleUp
//
//  Shot taxonomy. The whole app is architected around these from day one;
//  only `.forehandDink` / `.backhandDink` ship with a production analyzer.
//

import Foundation

/// Maturity of a shot's analysis pipeline. Surfaced in the UI so the player
/// always knows how much to trust a score.
nonisolated enum AnalyzerStatus: String, Codable, Sendable {
    /// Full rubric, tuned benchmarks, live coaching.
    case production
    /// Real rubric and real measurement, benchmarks not yet tuned.
    case preview
    /// Taxonomy + rubric defined, analyzer not implemented yet.
    case planned

    var label: String {
        switch self {
        case .production: return "Live"
        case .preview: return "Preview"
        case .planned: return "Coming soon"
        }
    }
}

/// Display grouping used by the player skill card (forehand/backhand dink
/// both roll up to a single "Dink" rating).
nonisolated enum ShotGroup: String, Codable, CaseIterable, Sendable, Identifiable {
    case dink, serve, returnOfServe, drive, volley, reset, thirdShotDrop, speedUp, overhead, block, rollVolley, lob

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dink: return "Dink"
        case .serve: return "Serve"
        case .returnOfServe: return "Return"
        case .drive: return "Drive"
        case .volley: return "Volley"
        case .reset: return "Reset"
        case .thirdShotDrop: return "Third-Shot Drop"
        case .speedUp: return "Speed-Up"
        case .overhead: return "Overhead"
        case .block: return "Block"
        case .rollVolley: return "Roll Volley"
        case .lob: return "Lob"
        }
    }

    var symbol: String {
        switch self {
        case .dink: return "circle.grid.cross"
        case .serve: return "hand.raised"
        case .returnOfServe: return "arrow.uturn.left"
        case .drive: return "bolt.horizontal"
        case .volley: return "square.grid.3x3"
        case .reset: return "circle.dashed"
        case .thirdShotDrop: return "scope"
        case .speedUp: return "hare"
        case .overhead: return "arrow.up.circle"
        case .block: return "shield"
        case .rollVolley: return "tornado"
        case .lob: return "arrow.up.right"
        }
    }
}

nonisolated enum ShotType: String, Codable, CaseIterable, Sendable, Identifiable {
    case forehandDink
    case backhandDink
    case forehandDrive
    case backhandDrive
    case forehandVolley
    case backhandVolley
    case reset
    case thirdShotDrop
    case serve
    case returnOfServe
    case speedUp
    case overhead
    case rollVolley
    case block
    case lob

    nonisolated var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forehandDink: return "Forehand Dink"
        case .backhandDink: return "Backhand Dink"
        case .forehandDrive: return "Forehand Drive"
        case .backhandDrive: return "Backhand Drive"
        case .forehandVolley: return "Forehand Volley"
        case .backhandVolley: return "Backhand Volley"
        case .reset: return "Reset"
        case .thirdShotDrop: return "Third-Shot Drop"
        case .serve: return "Serve"
        case .returnOfServe: return "Return"
        case .speedUp: return "Speed-Up"
        case .overhead: return "Overhead"
        case .rollVolley: return "Roll Volley"
        case .block: return "Block"
        case .lob: return "Lob"
        }
    }

    var group: ShotGroup {
        switch self {
        case .forehandDink, .backhandDink: return .dink
        case .forehandDrive, .backhandDrive: return .drive
        case .forehandVolley, .backhandVolley: return .volley
        case .reset: return .reset
        case .thirdShotDrop: return .thirdShotDrop
        case .serve: return .serve
        case .returnOfServe: return .returnOfServe
        case .speedUp: return .speedUp
        case .overhead: return .overhead
        case .rollVolley: return .rollVolley
        case .block: return .block
        case .lob: return .lob
        }
    }

    /// Whether the swing is played on the dominant-hand side of the body.
    var isForehandSide: Bool {
        switch self {
        case .backhandDink, .backhandDrive, .backhandVolley: return false
        default: return true
        }
    }

    var analyzerStatus: AnalyzerStatus {
        switch self {
        case .forehandDink, .backhandDink: return .production
        case .reset, .thirdShotDrop, .serve: return .preview
        default: return .planned
        }
    }

    var summary: String {
        switch self {
        case .forehandDink, .backhandDink:
            return "Soft, controlled shot from the kitchen line."
        case .reset:
            return "Absorb pace and drop the ball back into the kitchen."
        case .thirdShotDrop:
            return "Arcing drop from the baseline to win the net."
        case .serve:
            return "Underhand delivery that starts the point."
        case .forehandDrive, .backhandDrive:
            return "Flat, driven ball from mid-court or baseline."
        case .forehandVolley, .backhandVolley:
            return "Punch volley taken out of the air at the net."
        case .returnOfServe:
            return "Deep return that buys time to reach the kitchen."
        case .speedUp:
            return "Sudden attack out of a dink exchange."
        case .overhead:
            return "Put-away smash on a short lob."
        case .rollVolley:
            return "Topspin roll taken out of the air."
        case .block:
            return "Soft-hands defensive answer to a speed-up."
        case .lob:
            return "High, deep ball over the opponents at the net."
        }
    }

    /// Shots the player can actually start a practice session with today.
    static var practiceable: [ShotType] {
        allCases.filter { $0.analyzerStatus != .planned }
    }
}
