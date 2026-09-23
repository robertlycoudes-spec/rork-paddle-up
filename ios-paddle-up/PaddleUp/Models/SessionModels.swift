//
//  SessionModels.swift
//  PaddleUp
//
//  Persisted domain entities: profile, sessions, reps, mechanic history.
//  All Codable and `nonisolated` so they can be decoded off the main actor.
//

import Foundation

/// The player's level as a DUPR band. One selector serves both audiences:
/// players who know their DUPR pick the band it falls in; players who don't
/// pick by the plain-language label. Only the band is stored — never a
/// precise rating.
nonisolated enum DuprRange: String, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case beginner, lowerIntermediate, intermediate, upperIntermediate, advanced, advancedPlus, pro
    nonisolated var id: String { rawValue }

    /// The DUPR band, e.g. "3.0–3.49".
    var rangeLabel: String {
        switch self {
        case .beginner: return "2.0–2.49"
        case .lowerIntermediate: return "2.5–2.99"
        case .intermediate: return "3.0–3.49"
        case .upperIntermediate: return "3.5–3.99"
        case .advanced: return "4.0–4.49"
        case .advancedPlus: return "4.5–4.99"
        case .pro: return "5.0+"
        }
    }

    /// The plain-language label for players who don't know their DUPR.
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .lowerIntermediate: return "Lower Intermediate"
        case .intermediate: return "Intermediate"
        case .upperIntermediate: return "Upper Intermediate"
        case .advanced: return "Advanced"
        case .advancedPlus: return "Advanced+"
        case .pro: return "Pro"
        }
    }

    var detail: String {
        switch self {
        case .beginner: return "Learning the rules, the serve and keeping a rally going"
        case .lowerIntermediate: return "Rallying comfortably, starting to play at the kitchen"
        case .intermediate: return "Dinking with control, working on the third shot"
        case .upperIntermediate: return "Consistent drops and resets, playing with intent"
        case .advanced: return "Strong hands battles, attacking the right balls"
        case .advancedPlus: return "Tournament-level consistency under pressure"
        case .pro: return "Competing at the top of the sport"
        }
    }

    /// Full label used in settings and summaries: "3.0–3.49 · Intermediate".
    var fullLabel: String { "\(rangeLabel) · \(displayName)" }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: DuprRange, rhs: DuprRange) -> Bool { lhs.order < rhs.order }

    /// Maps the retired five-step skill level onto the nearest DUPR band so
    /// profiles saved before schema v2 keep a sensible level.
    static func migrating(legacySkillLevel raw: String) -> DuprRange? {
        switch raw {
        case "justStarting", "beginner": return .beginner
        case "intermediate": return .intermediate
        case "advanced": return .upperIntermediate
        case "competitive": return .advanced
        default: return nil
        }
    }
}

/// How the player describes their style of play. Single-select during
/// onboarding; shapes the balance of the generated plan (an aggressive player
/// gets a soft-game counterweight, a defensive player gets offence, etc.).
nonisolated enum PlayerStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case aggressive, defensive, consistent, athletic, strategic, figuringOut
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .aggressive: return "Aggressive"
        case .defensive: return "Defensive"
        case .consistent: return "Consistent"
        case .athletic: return "Fast / Athletic"
        case .strategic: return "Strategic"
        case .figuringOut: return "Still figuring out my style"
        }
    }
    var symbol: String {
        switch self {
        case .aggressive: return "bolt.fill"
        case .defensive: return "shield.lefthalf.filled"
        case .consistent: return "target"
        case .athletic: return "hare.fill"
        case .strategic: return "brain.head.profile"
        case .figuringOut: return "questionmark.circle"
        }
    }
}

/// The outcome the player would call proof the app is working. Single-select;
/// used to frame the plan's result so success is defined in their terms.
nonisolated enum SuccessMetric: String, Codable, CaseIterable, Sendable, Identifiable {
    case fewerErrors, winMoreGames, consistency, beatBetterPlayers, higherDUPR, confidence, winTournaments
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fewerErrors: return "Fewer unforced errors"
        case .winMoreGames: return "Winning more games"
        case .consistency: return "Better consistency"
        case .beatBetterPlayers: return "Beating better players"
        case .higherDUPR: return "Higher DUPR"
        case .confidence: return "Better confidence"
        case .winTournaments: return "Winning tournaments"
        }
    }
}

/// What the player wants to improve. Multi-select during onboarding.
nonisolated enum TrainingGoal: String, Codable, CaseIterable, Sendable, Identifiable {
    case consistency, serve, returnOfServe, dinking, thirdShotDrops, drives, volleys, speedReaction, strategyIQ, competitive
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .consistency: return "Consistency"
        case .serve: return "Serve"
        case .returnOfServe: return "Return"
        case .dinking: return "Dinking"
        case .thirdShotDrops: return "Third-shot drops"
        case .drives: return "Drives"
        case .volleys: return "Volleys"
        case .speedReaction: return "Speed & reaction"
        case .strategyIQ: return "Strategy / IQ"
        case .competitive: return "Become more competitive"
        }
    }
    var symbol: String {
        switch self {
        case .consistency: return "target"
        case .serve: return "hand.raised"
        case .returnOfServe: return "arrow.uturn.left"
        case .dinking: return "circle.grid.cross"
        case .thirdShotDrops: return "scope"
        case .drives: return "bolt.horizontal"
        case .volleys: return "square.grid.3x3"
        case .speedReaction: return "hare"
        case .strategyIQ: return "brain.head.profile"
        case .competitive: return "trophy"
        }
    }
}

/// The player's own read on what is holding them back. Multi-select during
/// onboarding; Paddle Up verifies these with measured data later.
nonisolated enum BiggestStruggle: String, Codable, CaseIterable, Sendable, Identifiable {
    case unforcedErrors, serveNeedsWork, consistency, kitchenPoints, thirdShot, betterPlayers, whatToPractice, fitness
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .unforcedErrors: return "I make too many unforced errors"
        case .serveNeedsWork: return "My serve needs work"
        case .consistency: return "I struggle with consistency"
        case .kitchenPoints: return "I lose points at the kitchen"
        case .thirdShot: return "My third shot needs improvement"
        case .betterPlayers: return "I struggle against better players"
        case .whatToPractice: return "I don't know what to practice"
        case .fitness: return "I get tired during games"
        }
    }
}

/// How much structured training time the player can commit each week.
nonisolated enum WeeklyTrainingTime: String, Codable, CaseIterable, Sendable, Identifiable {
    case light, moderate, serious, elite
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .light: return "1–2 hours"
        case .moderate: return "3–4 hours"
        case .serious: return "5–7 hours"
        case .elite: return "8+ hours"
        }
    }
    /// Weekly structured training budget in minutes.
    var weeklyMinutes: Int {
        switch self {
        case .light: return 90
        case .moderate: return 150
        case .serious: return 240
        case .elite: return 330
        }
    }
    /// Scales rep prescriptions in the generated plan.
    var repScale: Double {
        switch self {
        case .light: return 0.85
        case .moderate: return 1.0
        case .serious: return 1.35
        case .elite: return 1.7
        }
    }
    var practiceDaysPerWeek: Int {
        switch self {
        case .light: return 2
        case .moderate: return 3
        case .serious: return 4
        case .elite: return 5
        }
    }
}

nonisolated enum PlayFrequency: String, Codable, CaseIterable, Sendable, Identifiable {
    case rarely, weekly, fewTimesWeek, daily
    nonisolated var id: String { rawValue }
    var displayName: String {
        switch self {
        case .rarely: return "Less than once a week"
        case .weekly: return "1–2 times a week"
        case .fewTimesWeek: return "3–4 times a week"
        case .daily: return "5+ times a week"
        }
    }
}

/// The player's profile and preferences.
nonisolated struct PlayerProfile: Codable, Sendable, Equatable {
    var displayName: String = ""
    var email: String = ""
    /// The selected DUPR band. `nil` until the player picks one.
    var duprRange: DuprRange?
    var handedness: Handedness = .right
    var playerTypes: [PlayerStyle] = []
    var goals: [TrainingGoal] = []
    var struggles: [BiggestStruggle] = []
    var trainingTime: WeeklyTrainingTime = .moderate
    var successMetric: SuccessMetric?
    var frequency: PlayFrequency = .weekly
    var heightCentimetres: Int = 178
    var hasCompletedOnboarding: Bool = false
    var hasCompletedBaselineAssessment: Bool = false
    var createdAt: Date = .now

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "PU" : letters.joined().uppercased()
    }
}

extension PlayerProfile {
    nonisolated enum CodingKeys: String, CodingKey {
        case displayName, email, duprRange, handedness, playerTypes, goals, struggles
        case skillLevel // legacy five-step level, migrated to duprRange in schema v2
        case playerType // legacy single-select key from before multi-select
        case trainingTime, successMetric, frequency
        case heightCentimetres, hasCompletedOnboarding, hasCompletedBaselineAssessment, createdAt
    }

    // Encoded manually because CodingKeys includes legacy read-only keys,
    // which block synthesized Encodable conformance.
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(duprRange, forKey: .duprRange)
        try container.encode(handedness, forKey: .handedness)
        try container.encode(playerTypes, forKey: .playerTypes)
        try container.encode(goals, forKey: .goals)
        try container.encode(struggles, forKey: .struggles)
        try container.encode(trainingTime, forKey: .trainingTime)
        try container.encodeIfPresent(successMetric, forKey: .successMetric)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(heightCentimetres, forKey: .heightCentimetres)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(hasCompletedBaselineAssessment, forKey: .hasCompletedBaselineAssessment)
        try container.encode(createdAt, forKey: .createdAt)
    }

    /// Tolerant decoding: profiles saved by earlier versions of the app (with
    /// different profile fields) still load, missing fields fall back to defaults.
    /// Retired fields (weaknesses, motivation, competitiveness) are ignored.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        let legacyLevel = (try? container.decodeIfPresent(String.self, forKey: .skillLevel)) ?? nil
        let storedRange: DuprRange? = (try? container.decodeIfPresent(DuprRange.self, forKey: .duprRange)) ?? nil
        duprRange = storedRange ?? legacyLevel.flatMap(DuprRange.migrating(legacySkillLevel:))
        handedness = try container.decodeIfPresent(Handedness.self, forKey: .handedness) ?? .right
        let legacyPlayerType = (try? container.decodeIfPresent(PlayerStyle.self, forKey: .playerType)) ?? nil
        playerTypes = try container.decodeIfPresent([PlayerStyle].self, forKey: .playerTypes)
            ?? legacyPlayerType.map { [$0] } ?? []
        goals = try container.decodeIfPresent([TrainingGoal].self, forKey: .goals) ?? []
        struggles = try container.decodeIfPresent([BiggestStruggle].self, forKey: .struggles) ?? []
        trainingTime = try container.decodeIfPresent(WeeklyTrainingTime.self, forKey: .trainingTime) ?? .moderate
        successMetric = (try? container.decodeIfPresent(SuccessMetric.self, forKey: .successMetric)) ?? nil
        frequency = try container.decodeIfPresent(PlayFrequency.self, forKey: .frequency) ?? .weekly
        heightCentimetres = try container.decodeIfPresent(Int.self, forKey: .heightCentimetres) ?? 178
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        hasCompletedBaselineAssessment = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedBaselineAssessment) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}

/// One measured mechanic inside a rep.
nonisolated struct MechanicScore: Codable, Sendable, Identifiable, Equatable {
    let mechanic: MechanicID
    /// 0...100.
    let score: Double
    /// Raw pose-derived measurement in the benchmark's unit.
    let rawValue: Double
    let unit: String
    /// 0...1 measurement confidence.
    let confidence: Double

    nonisolated var id: String { mechanic.rawValue }
}

nonisolated struct RepRecord: Codable, Sendable, Identifiable, Equatable {
    var id: UUID = UUID()
    var sessionID: UUID
    var index: Int
    var timestamp: Date
    var shot: ShotType
    /// Overall 0...100 Paddle Up score for the rep.
    var score: Double
    var mechanics: [MechanicScore]
    var dominantIssue: MechanicID?
    var issueID: String?
    var correction: String
    var nextRepCue: String
    var recommendedDrillID: String?
    /// Detector confidence that this was a real, well-measured rep.
    var confidence: Double
    var isDeleted: Bool = false
    /// True when the player corrected the auto-classified shot type.
    var wasReclassified: Bool = false
    /// Relative filename of the saved 2–4s clip, if one was kept.
    var clipFilename: String?
    /// Pose frames spanning the rep, used for replay overlay and Swing Match.
    var poseFrames: [PoseFrame] = []
    var rubricVersion: Int = 1
    var benchmarkVersion: String = BenchmarkLibrary.version

    // MARK: Ball & paddle data — reserved, not yet measured.
    // Paddle Up only measures the body today. These stay `nil` until ball and
    // paddle tracking exists; nothing in the app estimates or fills them.

    /// Ball speed off the paddle, in mph.
    var ballSpeedMPH: Double?
    /// Ball spin, in revolutions per minute.
    var spinRPM: Double?
    /// Paddle face angle at contact, in degrees from vertical.
    var paddleFaceAngleDegrees: Double?
    /// How close contact was to the ideal moment, in milliseconds (lower is better).
    var contactTimingPrecisionMS: Double?

    /// True when the player had opted in to share anonymized data at the time
    /// this rep was recorded. Only flags the record — nothing is sent anywhere.
    var sharedForResearch: Bool = false

    func mechanic(_ id: MechanicID) -> MechanicScore? { mechanics.first { $0.mechanic == id } }
}

extension RepRecord {
    nonisolated enum CodingKeys: String, CodingKey {
        case id, sessionID, index, timestamp, shot, score, mechanics, dominantIssue, issueID
        case correction, nextRepCue, recommendedDrillID, confidence, isDeleted, wasReclassified
        case clipFilename, poseFrames, rubricVersion, benchmarkVersion
        case ballSpeedMPH, spinRPM, paddleFaceAngleDegrees, contactTimingPrecisionMS
        case sharedForResearch
    }

    /// Tolerant decoding so reps saved before schema v2 (without the reserved
    /// ball/paddle fields or the consent flag) still load.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        index = try container.decode(Int.self, forKey: .index)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        shot = try container.decode(ShotType.self, forKey: .shot)
        score = try container.decode(Double.self, forKey: .score)
        mechanics = try container.decodeIfPresent([MechanicScore].self, forKey: .mechanics) ?? []
        dominantIssue = try container.decodeIfPresent(MechanicID.self, forKey: .dominantIssue)
        issueID = try container.decodeIfPresent(String.self, forKey: .issueID)
        correction = try container.decodeIfPresent(String.self, forKey: .correction) ?? ""
        nextRepCue = try container.decodeIfPresent(String.self, forKey: .nextRepCue) ?? ""
        recommendedDrillID = try container.decodeIfPresent(String.self, forKey: .recommendedDrillID)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        wasReclassified = try container.decodeIfPresent(Bool.self, forKey: .wasReclassified) ?? false
        clipFilename = try container.decodeIfPresent(String.self, forKey: .clipFilename)
        poseFrames = try container.decodeIfPresent([PoseFrame].self, forKey: .poseFrames) ?? []
        rubricVersion = try container.decodeIfPresent(Int.self, forKey: .rubricVersion) ?? 1
        benchmarkVersion = try container.decodeIfPresent(String.self, forKey: .benchmarkVersion)
            ?? BenchmarkLibrary.version
        ballSpeedMPH = try container.decodeIfPresent(Double.self, forKey: .ballSpeedMPH)
        spinRPM = try container.decodeIfPresent(Double.self, forKey: .spinRPM)
        paddleFaceAngleDegrees = try container.decodeIfPresent(Double.self, forKey: .paddleFaceAngleDegrees)
        contactTimingPrecisionMS = try container.decodeIfPresent(Double.self, forKey: .contactTimingPrecisionMS)
        sharedForResearch = try container.decodeIfPresent(Bool.self, forKey: .sharedForResearch) ?? false
    }
}

nonisolated enum SessionMode: String, Codable, Sendable {
    case freePractice
    case drill
    case assessment

    var displayName: String {
        switch self {
        case .freePractice: return "Practice"
        case .drill: return "Drill"
        case .assessment: return "Assessment"
        }
    }
}

nonisolated struct SessionRecord: Codable, Sendable, Identifiable, Equatable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date?
    var shot: ShotType
    var mode: SessionMode
    var drillID: String?
    var reps: [RepRecord] = []
    /// Cue the player was asked to focus on during this session.
    var focusCue: String?
    /// True when the player had opted in to share anonymized data when this
    /// session was recorded. Only flags the record — nothing is sent anywhere.
    var sharedForResearch: Bool = false

    var activeReps: [RepRecord] { reps.filter { !$0.isDeleted } }

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    var averageScore: Double? {
        let scores = activeReps.map(\.score)
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    var bestScore: Double? { activeReps.map(\.score).max() }
    var worstScore: Double? { activeReps.map(\.score).min() }

    /// 100 minus the normalised spread of rep scores.
    var consistency: Double? {
        let scores = activeReps.map(\.score)
        guard scores.count > 1, let mean = averageScore else { return nil }
        let variance = scores.reduce(0) { $0 + pow($1 - mean, 2) } / Double(scores.count)
        let sd = sqrt(variance)
        return max(0, min(100, 100 - sd * 2.4))
    }

    /// Average of each mechanic across the session's reps.
    var mechanicAverages: [MechanicID: Double] {
        var totals: [MechanicID: (sum: Double, count: Int)] = [:]
        for rep in activeReps {
            for mechanic in rep.mechanics {
                let existing = totals[mechanic.mechanic] ?? (0, 0)
                totals[mechanic.mechanic] = (existing.sum + mechanic.score, existing.count + 1)
            }
        }
        return totals.compactMapValues { $0.count > 0 ? $0.sum / Double($0.count) : nil }
    }

    /// Mechanics in rubric order, so summaries read consistently.
    var orderedMechanicAverages: [(mechanic: MechanicID, score: Double)] {
        let averages = mechanicAverages
        return RubricLibrary.rubric(for: shot).components.compactMap { component in
            averages[component.mechanic].map { (component.mechanic, $0) }
        }
    }

    var weakestMechanic: (mechanic: MechanicID, score: Double)? {
        orderedMechanicAverages.min { $0.score < $1.score }
    }
}

extension SessionRecord {
    nonisolated enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, shot, mode, drillID, reps, focusCue, sharedForResearch
    }

    /// Tolerant decoding so sessions saved before schema v2 still load.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        shot = try container.decode(ShotType.self, forKey: .shot)
        mode = try container.decode(SessionMode.self, forKey: .mode)
        drillID = try container.decodeIfPresent(String.self, forKey: .drillID)
        reps = try container.decodeIfPresent([RepRecord].self, forKey: .reps) ?? []
        focusCue = try container.decodeIfPresent(String.self, forKey: .focusCue)
        sharedForResearch = try container.decodeIfPresent(Bool.self, forKey: .sharedForResearch) ?? false
    }
}

/// Snapshot of a mechanic's score at a point in time; the progress backbone.
nonisolated struct MechanicHistoryPoint: Codable, Sendable, Identifiable, Equatable {
    var id: UUID = UUID()
    let date: Date
    let shot: ShotType
    let mechanic: MechanicID
    let score: Double
}

/// Per-shot-group rating shown on the skill card.
nonisolated struct ShotRating: Codable, Sendable, Identifiable, Equatable {
    let group: ShotGroup
    let score: Double
    let previousScore: Double?
    let repCount: Int

    nonisolated var id: String { group.rawValue }
    var delta: Double? { previousScore.map { score - $0 } }
}

nonisolated struct Achievement: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String
    var earnedAt: Date
    var symbol: String
}

/// A recorded user correction (deleted rep / reclassified shot). Kept so the
/// detector and classifier can be improved from real usage later.
nonisolated struct UserFeedbackRecord: Codable, Sendable, Identifiable, Equatable {
    enum Kind: String, Codable, Sendable {
        case repDeleted
        case shotReclassified
        case scoreDisputed
    }

    var id: UUID = UUID()
    var repID: UUID
    var sessionID: UUID
    var kind: Kind
    var originalShot: ShotType
    var correctedShot: ShotType?
    var createdAt: Date = .now
    var note: String?
}
