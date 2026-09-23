//
//  AppState.swift
//  PaddleUp
//
//  Single source of truth for the signed-in player's data. Owns persistence,
//  derives ratings/progress, and prescribes drills and plans.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    private let store = PersistenceStore()
    private var accountID: String?
    private var saveTask: Task<Void, Never>?

    private(set) var data = AccountData()
    let analytics = Analytics()

    /// Called after every local change is written, so the sync layer can push.
    /// Set by the root view once cloud sync is wired.
    var onLocalChange: (() -> Void)?

    /// The account currently loaded, if any.
    var currentAccountID: String? { accountID }

    var profile: PlayerProfile { data.profile }
    var settings: AppSettings { data.settings }
    var sessions: [SessionRecord] { data.sessions }

    /// Sessions newest first, excluding empty ones.
    var completedSessions: [SessionRecord] {
        data.sessions
            .filter { $0.endedAt != nil && !$0.activeReps.isEmpty }
            .sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: - Account lifecycle

    func load(accountID: String, email: String, displayName: String) {
        self.accountID = accountID
        if let loaded = store.load(accountID: accountID) {
            data = loaded
        } else {
            data = AccountData()
            data.profile.displayName = displayName
            data.profile.email = email
        }
        if data.profile.displayName.isEmpty { data.profile.displayName = displayName }
        if data.profile.email.isEmpty { data.profile.email = email }
        // Profiles saved before the new onboarding ran have no level; send them
        // through onboarding again rather than personalising on nothing.
        if data.profile.hasCompletedOnboarding && data.profile.duprRange == nil {
            data.profile.hasCompletedOnboarding = false
        }
        analytics.isEnabled = data.settings.analyticsEnabled
        store.purgeExpiredClips(accountID: accountID, retentionDays: data.settings.clipRetentionDays)
        store.save(data, accountID: accountID)
    }

    /// Replaces local data with a newer snapshot from the cloud (last write
    /// wins). Clip filenames that don't exist on this device are dropped so the
    /// replay falls back to the stored pose frames.
    func applyRemote(_ remote: AccountData) {
        guard let accountID else { return }
        var incoming = PersistenceStore.migrate(remote)
        for sessionIndex in incoming.sessions.indices {
            for repIndex in incoming.sessions[sessionIndex].reps.indices {
                if let clip = incoming.sessions[sessionIndex].reps[repIndex].clipFilename,
                   let url = clipURL(for: clip), !FileManager.default.fileExists(atPath: url.path) {
                    incoming.sessions[sessionIndex].reps[repIndex].clipFilename = nil
                }
            }
        }
        data = incoming
        analytics.isEnabled = data.settings.analyticsEnabled
        Haptics.enabled = data.settings.hapticFeedback
        saveTask?.cancel()
        store.save(data, accountID: accountID)
    }

    func unload() {
        flush()
        accountID = nil
        data = AccountData()
    }

    func deleteEverything() {
        guard let accountID else { return }
        saveTask?.cancel()
        store.deleteAccount(accountID: accountID)
        data = AccountData()
    }

    var clipsDirectory: URL? {
        accountID.map { store.clipsDirectory(for: $0) }
    }

    func clipURL(for filename: String) -> URL? {
        clipsDirectory?.appendingPathComponent(filename)
    }

    var clipStorageDescription: String {
        guard let accountID else { return "0 KB" }
        let bytes = store.clipStorageBytes(accountID: accountID)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Removes every saved clip but keeps scores and mechanic history.
    func deleteAllClips() {
        guard let accountID else { return }
        store.deleteAllClips(accountID: accountID)
        for sessionIndex in data.sessions.indices {
            for repIndex in data.sessions[sessionIndex].reps.indices {
                data.sessions[sessionIndex].reps[repIndex].clipFilename = nil
            }
        }
        persist()
    }

    /// Erases all practice data while keeping the account and profile.
    func deleteAllPracticeData() {
        guard let accountID else { return }
        store.deleteAllClips(accountID: accountID)
        data.sessions.removeAll()
        data.mechanicHistory.removeAll()
        data.achievements.removeAll()
        data.feedback.removeAll()
        data.plan = nil
        data.profile.hasCompletedBaselineAssessment = false
        analytics.reset()
        persist()
    }

    // MARK: - Persistence

    /// Debounced write so rapid rep updates don't thrash the disk. Every local
    /// change stamps `modifiedAt`, which cloud sync uses for last-write-wins.
    private func persist() {
        guard let accountID else { return }
        data.modifiedAt = .now
        saveTask?.cancel()
        let snapshot = data
        saveTask = Task { [store, weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            store.save(snapshot, accountID: accountID)
            self?.onLocalChange?()
        }
    }

    func flush() {
        guard let accountID else { return }
        saveTask?.cancel()
        store.save(data, accountID: accountID)
    }

    // MARK: - Profile & settings

    func updateProfile(_ transform: (inout PlayerProfile) -> Void) {
        transform(&data.profile)
        persist()
    }

    func updateSettings(_ transform: (inout AppSettings) -> Void) {
        transform(&data.settings)
        analytics.isEnabled = data.settings.analyticsEnabled
        Haptics.enabled = data.settings.hapticFeedback
        persist()
    }

    /// Saves a draft of the onboarding answers as they're being collected, so
    /// nothing is lost if the app is killed mid-flow.
    func saveOnboardingDraft(_ answers: OnboardingAnswers) {
        if !answers.name.isEmpty { data.profile.displayName = answers.name }
        if let range = answers.duprRange { data.profile.duprRange = range }
        data.profile.playerTypes = answers.playerTypes
        data.profile.frequency = answers.frequency
        data.profile.goals = answers.goals
        data.profile.struggles = answers.struggles
        data.profile.trainingTime = answers.trainingTime
        data.profile.successMetric = answers.successMetric
        persist()
    }

    /// Completes onboarding: stores the answers and installs the personalised
    /// weekly plan the player was shown.
    func completeOnboarding(_ answers: OnboardingAnswers) {
        saveOnboardingDraft(answers)
        data.profile.hasCompletedOnboarding = true
        data.plan = buildPlan()
        analytics.record(.onboardingComplete, properties: [
            "duprRange": answers.duprRange?.rawValue ?? "",
            "playerTypes": answers.playerTypes.map(\.rawValue).joined(separator: ","),
            "frequency": answers.frequency.rawValue,
            "goals": answers.goals.map(\.rawValue).joined(separator: ","),
            "struggles": answers.struggles.map(\.rawValue).joined(separator: ","),
            "time": answers.trainingTime.rawValue,
            "successMetric": answers.successMetric?.rawValue ?? ""
        ])
        persist()
    }

    // MARK: - Sessions

    func save(session incoming: SessionRecord) {
        // Consent flags are stamped from the current setting when a record is
        // first seen, and never cleared retroactively by this path.
        var session = incoming
        if data.settings.shareAnonymizedData {
            session.sharedForResearch = true
            for index in session.reps.indices { session.reps[index].sharedForResearch = true }
        }
        if let index = data.sessions.firstIndex(where: { $0.id == session.id }) {
            data.sessions[index] = session
        } else {
            data.sessions.append(session)
        }

        // Record one mechanic-history point per mechanic per session, so
        // progress is stored at mechanic granularity, not just overall score.
        data.mechanicHistory.removeAll { point in
            point.date == session.startedAt && point.shot == session.shot
        }
        for (mechanic, score) in session.mechanicAverages {
            data.mechanicHistory.append(MechanicHistoryPoint(
                date: session.startedAt, shot: session.shot, mechanic: mechanic, score: score
            ))
        }

        if session.mode == .assessment && !session.activeReps.isEmpty {
            data.profile.hasCompletedBaselineAssessment = true
        }

        awardAchievements(for: session)
        regeneratePlanIfNeeded(afterSession: session)
        persist()
    }

    func session(id: UUID) -> SessionRecord? {
        data.sessions.first { $0.id == id }
    }

    func deleteSession(id: UUID) {
        if let session = data.sessions.first(where: { $0.id == id }), let accountID {
            for rep in session.reps {
                if let clip = rep.clipFilename {
                    store.deleteClip(named: clip, accountID: accountID)
                }
            }
        }
        data.sessions.removeAll { $0.id == id }
        data.mechanicHistory.removeAll { point in
            !data.sessions.contains { $0.startedAt == point.date && $0.shot == point.shot }
        }
        persist()
    }

    // MARK: - Rep corrections

    func deleteRep(_ rep: RepRecord) {
        guard let sessionIndex = data.sessions.firstIndex(where: { $0.id == rep.sessionID }),
              let repIndex = data.sessions[sessionIndex].reps.firstIndex(where: { $0.id == rep.id })
        else { return }

        data.sessions[sessionIndex].reps[repIndex].isDeleted = true
        if let clip = rep.clipFilename, let accountID {
            store.deleteClip(named: clip, accountID: accountID)
            data.sessions[sessionIndex].reps[repIndex].clipFilename = nil
        }
        data.feedback.append(UserFeedbackRecord(
            repID: rep.id, sessionID: rep.sessionID, kind: .repDeleted, originalShot: rep.shot
        ))
        analytics.record(.repDeleted, properties: ["shot": rep.shot.rawValue])
        refreshHistory(for: data.sessions[sessionIndex])
        persist()
    }

    func reclassifyRep(_ rep: RepRecord, to shot: ShotType) {
        guard let sessionIndex = data.sessions.firstIndex(where: { $0.id == rep.sessionID }),
              let repIndex = data.sessions[sessionIndex].reps.firstIndex(where: { $0.id == rep.id })
        else { return }

        data.sessions[sessionIndex].reps[repIndex].shot = shot
        data.sessions[sessionIndex].reps[repIndex].wasReclassified = true
        data.feedback.append(UserFeedbackRecord(
            repID: rep.id, sessionID: rep.sessionID, kind: .shotReclassified,
            originalShot: rep.shot, correctedShot: shot
        ))
        analytics.record(.classificationCorrected,
                         properties: ["from": rep.shot.rawValue, "to": shot.rawValue])
        persist()
    }

    private func refreshHistory(for session: SessionRecord) {
        data.mechanicHistory.removeAll { $0.date == session.startedAt && $0.shot == session.shot }
        for (mechanic, score) in session.mechanicAverages {
            data.mechanicHistory.append(MechanicHistoryPoint(
                date: session.startedAt, shot: session.shot, mechanic: mechanic, score: score
            ))
        }
    }

    // MARK: - Derived ratings

    private var allReps: [RepRecord] {
        data.sessions.flatMap { $0.activeReps }
    }

    func reps(for group: ShotGroup) -> [RepRecord] {
        allReps.filter { $0.shot.group == group }
    }

    /// Per-shot-group ratings for the skill card, best first.
    var shotRatings: [ShotRating] {
        ShotGroup.allCases.compactMap { group in
            let reps = reps(for: group).sorted { $0.timestamp < $1.timestamp }
            guard !reps.isEmpty, let score = ScoringEngine.rating(from: reps) else { return nil }

            // Previous rating = rating excluding the most recent session's reps.
            let mostRecentSession = data.sessions
                .filter { $0.shot.group == group && !$0.activeReps.isEmpty }
                .max { $0.startedAt < $1.startedAt }
            let older = reps.filter { $0.sessionID != mostRecentSession?.id }
            let previous = older.count >= 5 ? ScoringEngine.rating(from: older) : nil

            return ShotRating(group: group, score: score, previousScore: previous, repCount: reps.count)
        }
        .sorted { $0.score > $1.score }
    }

    /// Overall Paddle Up Rating. NOT a DUPR rating.
    var overallRating: Double? {
        ScoringEngine.overallRating(from: shotRatings)
    }

    /// Change in overall rating over the last 30 days.
    var overallRatingDelta: Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let older = data.sessions.filter { $0.startedAt < cutoff }.flatMap { $0.activeReps }
        guard older.count >= 8, let then = ScoringEngine.rating(from: older),
              let now = overallRating else { return nil }
        return now - then
    }

    var strongestShot: ShotRating? { shotRatings.first }
    var weakestShot: ShotRating? { shotRatings.last }

    var totalRepCount: Int { allReps.count }
    var completedSessionCount: Int { completedSessions.count }

    /// Consecutive days with at least one completed session, counting today or
    /// yesterday as the anchor.
    var practiceStreak: Int {
        let calendar = Calendar.current
        let days = Set(completedSessions.map { calendar.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: .now)
        var cursor = days.contains(today) ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard days.contains(cursor) else { return 0 }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - Mechanic progress

    /// Scores for one mechanic over time, oldest first.
    func history(for mechanic: MechanicID, group: ShotGroup? = nil) -> [MechanicHistoryPoint] {
        data.mechanicHistory
            .filter { point in
                point.mechanic == mechanic && (group == nil || point.shot.group == group)
            }
            .sorted { $0.date < $1.date }
    }

    /// Improvement in a mechanic over the trailing window.
    func improvement(for mechanic: MechanicID, group: ShotGroup? = nil, days: Int = 30) -> Double? {
        let points = history(for: mechanic, group: group)
        guard points.count >= 2 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let recent = points.filter { $0.date >= cutoff }
        guard let first = (recent.first ?? points.first), let last = points.last,
              first.id != last.id else { return nil }
        return last.score - first.score
    }

    /// The mechanic that improved most in the trailing window.
    var biggestImprovement: (mechanic: MechanicID, delta: Double, group: ShotGroup)? {
        var best: (MechanicID, Double, ShotGroup)?
        for group in ShotGroup.allCases {
            for mechanic in MechanicID.allCases {
                guard let delta = improvement(for: mechanic, group: group), delta > 0 else { continue }
                if best == nil || delta > best!.1 { best = (mechanic, delta, group) }
            }
        }
        return best.map { (mechanic: $0.0, delta: $0.1, group: $0.2) }
    }

    /// Weekly averages of a shot group's score, for the trend chart.
    func weeklyTrend(for group: ShotGroup, weeks: Int = 4) -> [(label: String, score: Double)] {
        let calendar = Calendar.current
        let reps = reps(for: group)
        guard !reps.isEmpty else { return [] }

        var buckets: [(label: String, scores: [Double])] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset,
                                                to: calendar.startOfDay(for: .now)),
                  let rangeStart = calendar.date(byAdding: .day, value: -6, to: weekStart) else { continue }
            let inWeek = reps.filter { $0.timestamp >= rangeStart && $0.timestamp <= weekStart.addingTimeInterval(86_400) }
            buckets.append((label: "Week \(weeks - offset)", scores: inWeek.map(\.score)))
        }

        // Carry the last known value forward so the line stays continuous.
        var carried: Double?
        return buckets.compactMap { bucket in
            if bucket.scores.isEmpty {
                guard let carried else { return nil }
                return (bucket.label, carried)
            }
            let average = bucket.scores.reduce(0, +) / Double(bucket.scores.count)
            carried = average
            return (bucket.label, average)
        }
    }

    // MARK: - Recommendations

    /// Today's recommended drill, derived from the player's weakest measured
    /// mechanic — or a sensible starting drill for a brand-new player.
    var recommendedDrill: Drill? {
        if let insight = recurringWeaknesses.first,
           let drill = insight.drillID.flatMap(DrillLibrary.drill(id:)) {
            return drill
        }
        if let latest = completedSessions.first,
           let focus = CoachingEngine.sessionFocus(for: latest),
           let drill = focus.drillID.flatMap(DrillLibrary.drill(id:)) {
            return drill
        }
        // No data yet: start from the onboarding game plan.
        let shot = GamePlanEngine.focusShot(for: profile)
        return DrillLibrary.drills(for: shot).first
    }

    var recurringWeaknesses: [WeaknessInsight] {
        CoachingEngine.recurringWeaknesses(sessions: completedSessions)
    }

    /// Swing Match results for a shot group.
    func swingMatches(for group: ShotGroup) -> [SwingMatchResult] {
        let reps = reps(for: group)
        guard let shot = reps.last?.shot else { return [] }
        return ReferenceMatcher.match(reps: reps, shot: shot)
    }

    // MARK: - Weekly plan

    var weeklyPlan: WeeklyPlan? { data.plan }

    func regeneratePlan() {
        data.plan = buildPlan()
        persist()
    }

    private func regeneratePlanIfNeeded(afterSession session: SessionRecord) {
        guard let plan = data.plan else {
            data.plan = buildPlan()
            return
        }
        // Refresh weekly, or as soon as the first completed session gives the
        // plan real measured data to replace the level-only starter week.
        let isFirstMeasuredSession = session.endedAt != nil && completedSessions.count == 1
            && completedSessions.first?.id == session.id
        if Date().timeIntervalSince(plan.generatedAt) > 7 * 86_400 || isFirstMeasuredSession {
            data.plan = buildPlan()
        }
    }

    func markPlanEntryComplete(_ entryID: UUID) {
        guard var plan = data.plan,
              let index = plan.entries.firstIndex(where: { $0.id == entryID }) else { return }
        plan.entries[index].completedAt = .now
        data.plan = plan
        persist()
    }

    /// Measured weak spots from real reps, most important first: recurring
    /// issues across sessions, then each recent session's weakest mechanic.
    private var measuredFocus: [MeasuredFocus] {
        var focus: [MeasuredFocus] = recurringWeaknesses.prefix(3).map {
            MeasuredFocus(shot: $0.shot, mechanic: $0.mechanic)
        }
        for session in completedSessions.prefix(4) {
            guard let weakest = session.weakestMechanic else { continue }
            let candidate = MeasuredFocus(shot: session.shot, mechanic: weakest.mechanic)
            if !focus.contains(candidate) { focus.append(candidate) }
        }
        return focus
    }

    /// Builds the week from the DUPR range plus measured practice data.
    private func buildPlan() -> WeeklyPlan {
        let lead = recurringWeaknesses.first.map {
            "\($0.mechanic.displayName.lowercased()) on the \($0.shot.group.displayName.lowercased())"
        }
        return GamePlanEngine.weeklyPlan(profile: profile, measured: measuredFocus, leadInsight: lead)
    }

    // MARK: - Achievements

    var achievements: [Achievement] {
        data.achievements.sorted { $0.earnedAt > $1.earnedAt }
    }

    private func awardAchievements(for session: SessionRecord) {
        guard let average = session.averageScore else { return }

        // Personal best for the shot group.
        let previousBest = data.sessions
            .filter { $0.id != session.id && $0.shot.group == session.shot.group }
            .compactMap(\.averageScore)
            .max()
        if let best = session.bestScore, (previousBest ?? 0) < average, session.activeReps.count >= 10 {
            award(id: "pb_\(session.shot.group.rawValue)_\(Int(best))",
                  title: "New personal best",
                  detail: "\(session.shot.group.displayName) score: \(Int(best))",
                  symbol: "trophy.fill")
        }

        let streak = practiceStreak
        if streak >= 3 {
            award(id: "streak_\(streak)", title: "\(streak)-day streak",
                  detail: "You practised \(streak) days in a row.", symbol: "flame.fill")
        }

        let reps = totalRepCount
        for milestone in [100, 500, 1000, 2500] where reps >= milestone {
            award(id: "reps_\(milestone)", title: "\(milestone) reps logged",
                  detail: "Every one of them measured.", symbol: "checkmark.seal.fill")
        }

        if let improvement = biggestImprovement, improvement.delta >= 8 {
            award(id: "improve_\(improvement.mechanic.rawValue)_\(Int(improvement.delta))",
                  title: "\(improvement.mechanic.displayName) +\(Int(improvement.delta))",
                  detail: "Measured improvement this month.", symbol: "chart.line.uptrend.xyaxis")
        }
    }

    private func award(id: String, title: String, detail: String, symbol: String) {
        guard !data.achievements.contains(where: { $0.id == id }) else { return }
        data.achievements.append(Achievement(id: id, title: title, detail: detail,
                                             earnedAt: .now, symbol: symbol))
    }
}
