//
//  Analytics.swift
//  PaddleUp
//
//  Product analytics.
//
//  TEMPORARY — LOCAL SINK: events are counted on-device and surfaced in
//  developer mode instead of being sent to a provider. The call sites and event
//  names are production-shaped, so wiring a real SDK means replacing only
//  `record(_:properties:)`.
//

import Foundation
import OSLog

nonisolated enum AnalyticsEvent: String, Sendable, CaseIterable {
    case onboardingComplete = "onboarding_complete"
    case assessmentStarted = "assessment_started"
    case assessmentCompleted = "assessment_completed"
    case practiceStarted = "practice_started"
    case practiceCompleted = "practice_completed"
    case repDetected = "rep_detected"
    case repRejected = "rep_rejected"
    case repDeleted = "rep_deleted"
    case classificationCorrected = "classification_corrected"
    case recommendationOpened = "recommendation_opened"
    case drillStarted = "drill_started"
    case drillCompleted = "drill_completed"
    case paywallViewed = "paywall_viewed"
    case subscriptionStarted = "subscription_started"
    case swingMatchViewed = "swing_match_viewed"
}

@MainActor
@Observable
final class Analytics {
    private let logger = Logger(subsystem: "app.paddleup", category: "analytics")
    private(set) var counts: [String: Int] = [:]
    private(set) var recent: [String] = []
    var isEnabled = true

    func record(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        guard isEnabled else { return }
        counts[event.rawValue, default: 0] += 1
        let detail = properties.isEmpty ? "" : " " + properties.map { "\($0)=\($1)" }.sorted().joined(separator: " ")
        let line = "\(event.rawValue)\(detail)"
        recent.insert(line, at: 0)
        if recent.count > 80 { recent.removeLast(recent.count - 80) }
        logger.debug("\(line, privacy: .public)")
    }

    /// Detection quality: share of candidate swings kept as real reps.
    var repAcceptanceRate: Double? {
        let detected = counts[AnalyticsEvent.repDetected.rawValue] ?? 0
        let rejected = counts[AnalyticsEvent.repRejected.rawValue] ?? 0
        let total = detected + rejected
        guard total > 0 else { return nil }
        return Double(detected) / Double(total)
    }

    /// Share of kept reps the player later deleted as false positives.
    var falsePositiveRate: Double? {
        let detected = counts[AnalyticsEvent.repDetected.rawValue] ?? 0
        let deleted = counts[AnalyticsEvent.repDeleted.rawValue] ?? 0
        guard detected > 0 else { return nil }
        return Double(deleted) / Double(detected)
    }

    func reset() {
        counts.removeAll()
        recent.removeAll()
    }
}
