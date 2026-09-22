//
//  CoachingEngine.swift
//  PaddleUp
//
//  Turns a structured RepAnalysis into coaching: one dominant issue, one
//  correction, one cue, one drill. The LLM is never asked to look at raw video
//  — measurement happens first, language second.
//

import Foundation

/// The coaching payload attached to a rep. Exactly ONE correction, by design.
nonisolated struct RepCoaching: Sendable {
    let issue: CoachingIssue?
    let headline: String
    let correction: String
    let cue: String
    let severity: IssueSeverity
    let drillID: String?

    var isPraise: Bool { issue == nil }
}

/// Recurring-weakness insight across multiple sessions.
nonisolated struct WeaknessInsight: Sendable, Identifiable {
    let id = UUID()
    let mechanic: MechanicID
    let shot: ShotType
    let sessionCount: Int
    let averageScore: Double
    let trend: Double
    let message: String
    let drillID: String?
}

nonisolated enum CoachingEngine {

    /// Coaching for a single rep.
    static func coach(analysis: RepAnalysis) -> RepCoaching {
        guard let dominant = analysis.dominantIssue,
              let mechanicScore = analysis.mechanics.first(where: { $0.mechanic == dominant }) else {
            return RepCoaching(
                issue: nil,
                headline: CoachingKnowledgeBase.praise(forScore: analysis.score),
                correction: "Nothing major to change — repeat exactly that.",
                cue: "SAME AGAIN",
                severity: .minor,
                drillID: nil
            )
        }

        let issue = CoachingKnowledgeBase.issue(for: dominant, shot: analysis.shot,
                                                valueIsHigh: analysis.dominantValueIsHigh)
        let severity = CoachingKnowledgeBase.severity(forScore: mechanicScore.score)

        guard let issue else {
            return RepCoaching(
                issue: nil,
                headline: "\(dominant.displayName) needs work",
                correction: "Focus on your \(dominant.displayName.lowercased()) on the next rep.",
                cue: dominant.shortCue,
                severity: severity,
                drillID: DrillLibrary.drill(for: dominant, shot: analysis.shot)?.id
            )
        }

        return RepCoaching(
            issue: issue,
            headline: issue.title,
            correction: issue.correction,
            cue: issue.cue,
            severity: severity,
            drillID: issue.drillID
        )
    }

    /// The session's single most important focus, from its reps.
    static func sessionFocus(for session: SessionRecord) -> RepCoaching? {
        let reps = session.activeReps
        guard !reps.isEmpty else { return nil }

        // Count how often each mechanic was the dominant issue, weighted by
        // how bad it was, so one terrible rep does not outvote a pattern.
        var burden: [MechanicID: Double] = [:]
        var highVotes: [MechanicID: Int] = [:]
        var lowVotes: [MechanicID: Int] = [:]

        for rep in reps {
            guard let dominant = rep.dominantIssue,
                  let score = rep.mechanic(dominant)?.score else { continue }
            burden[dominant, default: 0] += (100 - score)
            if let issueID = rep.issueID, let issue = CoachingKnowledgeBase.issue(id: issueID) {
                if issue.triggersOnHigh { highVotes[dominant, default: 0] += 1 }
                else { lowVotes[dominant, default: 0] += 1 }
            }
        }

        guard let (mechanic, _) = burden.max(by: { $0.value < $1.value }) else {
            let best = reps.map(\.score).reduce(0, +) / Double(reps.count)
            return RepCoaching(issue: nil, headline: CoachingKnowledgeBase.praise(forScore: best),
                               correction: "Keep repeating this shape.", cue: "SAME AGAIN",
                               severity: .minor, drillID: nil)
        }

        let valueIsHigh = (highVotes[mechanic] ?? 0) > (lowVotes[mechanic] ?? 0)
        let issue = CoachingKnowledgeBase.issue(for: mechanic, shot: session.shot, valueIsHigh: valueIsHigh)
        let average = session.mechanicAverages[mechanic] ?? 60

        return RepCoaching(
            issue: issue,
            headline: issue?.title ?? "\(mechanic.displayName) needs work",
            correction: issue?.correction ?? "Focus on your \(mechanic.displayName.lowercased()).",
            cue: issue?.cue ?? mechanic.shortCue,
            severity: CoachingKnowledgeBase.severity(forScore: average),
            drillID: issue?.drillID ?? DrillLibrary.drill(for: mechanic, shot: session.shot)?.id
        )
    }

    /// Recurring weaknesses across recent sessions — the "this has been your
    /// main issue across 4 sessions" insight.
    static func recurringWeaknesses(sessions: [SessionRecord], minimumSessions: Int = 2) -> [WeaknessInsight] {
        let relevant = sessions.filter { !$0.activeReps.isEmpty }
        guard relevant.count >= minimumSessions else { return [] }

        var grouped: [ShotType: [SessionRecord]] = [:]
        for session in relevant { grouped[session.shot, default: []].append(session) }

        var insights: [WeaknessInsight] = []

        for (shot, shotSessions) in grouped {
            let ordered = shotSessions.sorted { $0.startedAt < $1.startedAt }
            var appearances: [MechanicID: [Double]] = [:]

            for session in ordered {
                guard let weakest = session.weakestMechanic else { continue }
                appearances[weakest.mechanic, default: []].append(weakest.score)
            }

            for (mechanic, scores) in appearances where scores.count >= minimumSessions {
                let average = scores.reduce(0, +) / Double(scores.count)
                let trend = (scores.last ?? average) - (scores.first ?? average)
                let message: String
                if trend > 4 {
                    message = "\(shot.group.displayName) \(mechanic.displayName.lowercased()) has been your main issue across \(scores.count) sessions, but it is improving (+\(Int(trend.rounded()))). Keep the current drill."
                } else if trend < -4 {
                    message = "\(shot.group.displayName) \(mechanic.displayName.lowercased()) has been your main issue across \(scores.count) sessions and it is slipping (\(Int(trend.rounded()))). Slow the drill down."
                } else {
                    message = "\(shot.group.displayName) \(mechanic.displayName.lowercased()) has been your main issue across \(scores.count) sessions. It is not moving yet — commit to the prescribed drill."
                }

                insights.append(WeaknessInsight(
                    mechanic: mechanic,
                    shot: shot,
                    sessionCount: scores.count,
                    averageScore: average,
                    trend: trend,
                    message: message,
                    drillID: DrillLibrary.drill(for: mechanic, shot: shot)?.id
                ))
            }
        }

        return insights.sorted { $0.sessionCount > $1.sessionCount }
    }

    /// Structured analysis payload — what an LLM would be handed to explain.
    /// Exportable from developer mode.
    static func structuredPayload(for rep: RepRecord, trend: Double?) -> [String: String] {
        var payload: [String: String] = [
            "shotType": rep.shot.rawValue,
            "score": String(Int(rep.score)),
            "confidence": String(format: "%.2f", rep.confidence),
            "rubricVersion": String(rep.rubricVersion),
            "benchmarkVersion": rep.benchmarkVersion
        ]
        for mechanic in rep.mechanics {
            payload["\(mechanic.mechanic.rawValue)Score"] = String(Int(mechanic.score))
            payload["\(mechanic.mechanic.rawValue)Raw"] = String(format: "%.3f %@", mechanic.rawValue, mechanic.unit)
        }
        if let dominant = rep.dominantIssue { payload["dominantIssue"] = dominant.rawValue }
        if let issueID = rep.issueID { payload["issueID"] = issueID }
        if let trend { payload["trend"] = String(format: "%+.1f", trend) }
        return payload
    }
}
