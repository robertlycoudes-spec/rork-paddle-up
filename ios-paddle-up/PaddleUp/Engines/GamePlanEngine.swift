//
//  GamePlanEngine.swift
//  PaddleUp
//
//  Builds the player's game plan. Two inputs drive it:
//
//    1. The player's DUPR range — sets the starting curriculum, drill
//       difficulty and training volume.
//    2. Measured practice data — once sessions exist, the mechanics that
//       actually score lowest take over the plan's lead slots.
//
//  The remaining onboarding answers (style, goals, struggles, weekly time,
//  success metric) only fine-tune volume and add extra plan lines; they never
//  choose the core focus. A brand-new player with no sessions gets the
//  curriculum for their range. Deterministic and pure — the same inputs always
//  produce the same plan, so it is reproducible and testable.
//

import Foundation

/// Everything the onboarding flow collects, in order.
nonisolated struct OnboardingAnswers: Codable, Sendable, Equatable {
    var name: String = ""
    /// `nil` until the player picks a range.
    var duprRange: DuprRange?
    var playerTypes: [PlayerStyle] = []
    var frequency: PlayFrequency = .weekly
    var goals: [TrainingGoal] = []
    var struggles: [BiggestStruggle] = []
    var trainingTime: WeeklyTrainingTime = .moderate
    var successMetric: SuccessMetric?
}

/// One line of the this-week prescription.
nonisolated struct GamePlanItem: Identifiable, Sendable, Equatable {
    var id = UUID()
    let title: String
    let amount: Int
    /// "reps", "minutes", "sessions" — how `amount` is counted.
    let unit: String
    let symbol: String
}

/// The personalised result shown before the paywall.
nonisolated struct GamePlan: Sendable, Equatable {
    /// e.g. "Third-shot drops + dinking"
    let opportunity: String
    /// One line explaining why that opportunity matters.
    let opportunityDetail: String
    let items: [GamePlanItem]
    /// The single cue the coach will repeat first.
    let focusCue: String
    let weeklyMinutes: Int
    let practiceDays: Int
}

/// A measured weak spot from real reps: the shot and the mechanic that scored lowest.
nonisolated struct MeasuredFocus: Sendable, Equatable {
    let shot: ShotType
    let mechanic: MechanicID
}

nonisolated enum GamePlanEngine {

    /// Range used when a player has not picked one (legacy profiles only —
    /// onboarding requires a pick).
    static let defaultRange: DuprRange = .lowerIntermediate

    // MARK: - Level curriculum

    /// The skills a player in this range should build first, in priority
    /// order. This is the plan for a brand-new player with no sessions.
    static func curriculum(for range: DuprRange) -> [TrainingGoal] {
        switch range {
        case .beginner: return [.consistency, .dinking, .serve]
        case .lowerIntermediate: return [.dinking, .consistency, .returnOfServe]
        case .intermediate: return [.thirdShotDrops, .dinking, .consistency]
        case .upperIntermediate: return [.thirdShotDrops, .volleys, .dinking]
        case .advanced: return [.volleys, .thirdShotDrops, .drives]
        case .advancedPlus: return [.volleys, .drives, .speedReaction]
        case .pro: return [.speedReaction, .volleys, .drives]
        }
    }

    /// Multiplies prescribed rep counts: newer players start lighter.
    static func volumeScale(for range: DuprRange) -> Double {
        switch range {
        case .beginner: return 0.7
        case .lowerIntermediate: return 0.85
        case .intermediate: return 1.0
        case .upperIntermediate: return 1.1
        case .advanced: return 1.2
        case .advancedPlus: return 1.3
        case .pro: return 1.4
        }
    }

    /// Advanced ranges rehearse pressure, not just technique.
    static func wantsPressureWork(_ range: DuprRange) -> Bool { range >= .advanced }

    private static func levelNarrative(_ range: DuprRange) -> String {
        switch range {
        case .beginner:
            return "At 2.0–2.49 the fastest gains come from keeping the ball in play. We'll build a repeatable contact point and a reliable serve before anything else."
        case .lowerIntermediate:
            return "At 2.5–2.99 points are won and lost at the kitchen. We'll build a controlled dink and a deep return so you can get there and stay there."
        case .intermediate:
            return "At 3.0–3.49 the third shot decides whether you reach the kitchen at all. We'll build your drop on top of a steady dink."
        case .upperIntermediate:
            return "At 3.5–3.99 the gap is consistency under pace — clean drops, quiet hands at the line, and volleys that don't pop up."
        case .advanced:
            return "At 4.0–4.49 hands battles and shot selection decide games. We'll sharpen your volleys and keep your drop reliable when it matters."
        case .advancedPlus:
            return "At 4.5–4.99 the margins are small. We'll tighten your volley shape, add depth to your drives and speed up your first step."
        case .pro:
            return "At 5.0+ every rep is about marginal gains — reaction speed, a stable paddle in fast exchanges and drives with intent."
        }
    }

    // MARK: - Onboarding result

    /// Maps a struggle onto the shared TrainingGoal vocabulary. Struggles that
    /// don't map to a shot skill (direction, conditioning) return nil.
    static func struggleGoal(_ struggle: BiggestStruggle) -> TrainingGoal? {
        switch struggle {
        case .unforcedErrors: return .consistency
        case .serveNeedsWork: return .serve
        case .consistency: return .consistency
        case .kitchenPoints: return .dinking
        case .thirdShot: return .thirdShotDrops
        case .betterPlayers: return .strategyIQ
        case .whatToPractice: return nil
        case .fitness: return nil
        }
    }

    /// The core focus areas: the range's curriculum. Personal answers never
    /// reorder it — they only add extra lines in `generate`.
    static func focusAreas(for answers: OnboardingAnswers) -> [TrainingGoal] {
        curriculum(for: answers.duprRange ?? defaultRange)
    }

    static func generate(_ answers: OnboardingAnswers) -> GamePlan {
        let range = answers.duprRange ?? defaultRange
        let areas = curriculum(for: range)
        let primary = areas[0]
        let opportunity = "\(primary.displayName) + \(areas[1].displayName.lowercased())"
        let scale = answers.trainingTime.repScale * volumeScale(for: range)

        var items: [GamePlanItem] = []
        func add(_ item: GamePlanItem) {
            guard !items.contains(where: { $0.title == item.title }) else { return }
            items.append(item)
        }

        // Core: the curriculum for the player's range.
        for goal in areas { add(prescriptionItem(goal, scale: scale)) }

        // Fine-tuning: personal answers add lines but never replace the core.
        if wantsPressureWork(range) {
            add(GamePlanItem(title: "Scored, game-like reps",
                             amount: range >= .advancedPlus ? 3 : 2,
                             unit: "sessions", symbol: "trophy.fill"))
        }
        for goal in (answers.struggles.compactMap(struggleGoal) + answers.goals) where !areas.contains(goal) {
            add(prescriptionItem(goal, scale: scale))
        }
        for style in answers.playerTypes.prefix(2) {
            add(styleItem(for: style, scale: scale))
        }
        if answers.struggles.contains(.whatToPractice) {
            add(GamePlanItem(title: "Guided sessions with your AI coach",
                             amount: 3, unit: "sessions", symbol: "waveform"))
        }
        if answers.struggles.contains(.fitness), !items.contains(where: { $0.unit == "min" }) {
            add(GamePlanItem(title: "Footwork & conditioning",
                             amount: scaled(10, scale), unit: "min", symbol: "figure.run"))
        }

        return GamePlan(
            opportunity: opportunity,
            opportunityDetail: detailNarrative(range: range, answers: answers),
            // Keep the reveal glanceable — the plan adapts weekly anyway.
            items: Array(items.prefix(5)),
            focusCue: focusCue(for: answers, primary: primary),
            weeklyMinutes: answers.trainingTime.weeklyMinutes,
            practiceDays: answers.trainingTime.practiceDaysPerWeek
        )
    }

    private static func detailNarrative(range: DuprRange, answers: OnboardingAnswers) -> String {
        var sentences: [String] = [levelNarrative(range)]
        if let style = answers.playerTypes.first { sentences.append(styleClause(style)) }
        if let metric = answers.successMetric { sentences.append(successClause(metric)) }
        return sentences.joined(separator: " ")
    }

    /// A counterweight line chosen from one of the player's self-described styles.
    private static func styleItem(for style: PlayerStyle, scale: Double) -> GamePlanItem {
        switch style {
        case .aggressive:
            return GamePlanItem(title: "Soft resets to balance your attack",
                                amount: scaled(20, scale), unit: "reps", symbol: "arrow.down.left.circle")
        case .defensive:
            return GamePlanItem(title: "Attack the short ball",
                                amount: scaled(20, scale), unit: "reps", symbol: "bolt.horizontal")
        case .consistent:
            return GamePlanItem(title: "Streak challenges — 10 clean in a row",
                                amount: 5, unit: "sets", symbol: "repeat")
        case .athletic:
            return GamePlanItem(title: "Footwork & conditioning",
                                amount: scaled(10, scale), unit: "min", symbol: "figure.run")
        case .strategic:
            return GamePlanItem(title: "Strategy sessions",
                                amount: 2, unit: "sessions", symbol: "brain.head.profile")
        case .figuringOut:
            return GamePlanItem(title: "Guided sessions with your AI coach",
                                amount: 3, unit: "sessions", symbol: "waveform")
        }
    }

    private static func styleClause(_ style: PlayerStyle) -> String {
        switch style {
        case .aggressive:
            return "You play aggressive, so we keep your pace and add a reliable soft option — attack from the kitchen, not from no-man's land."
        case .defensive:
            return "You play defensive, so alongside that we'll train you to step in and finish the short ball instead of resetting it back."
        case .consistent:
            return "You already play consistent, so your reps are scored in streaks — the bar is clean repetition, not highlight shots."
        case .athletic:
            return "You're fast, so we'll convert that athleticism into position: early split-steps and balanced contact."
        case .strategic:
            return "You think the game, so your plan pairs every technical block with a pattern to run it inside."
        case .figuringOut:
            return "You're still finding your style, so your first weeks stay guided — Paddle Up will show you what your game is actually good at."
        }
    }

    private static func successClause(_ metric: SuccessMetric) -> String {
        switch metric {
        case .fewerErrors:
            return "You'll know it's working when your unforced errors drop — that's the number we track first."
        case .winMoreGames:
            return "You'll know it's working when you win more of the games you used to lose close."
        case .consistency:
            return "You'll know it's working when your rep scores tighten up — consistency is measured as your spread, not your best shot."
        case .beatBetterPlayers:
            return "You'll know it's working when stronger opponents stop getting free points off you."
        case .higherDUPR:
            return "Rating gains follow error reduction, so we'll track your Paddle Up score as the leading indicator of your rating."
        case .confidence:
            return "You'll know it's working when you stop second-guessing the shot mid-swing."
        case .winTournaments:
            return "You'll know it's working when your game holds up on tournament day, so we rehearse pressure, not just technique."
        }
    }

    private static func prescriptionTitle(_ goal: TrainingGoal) -> String {
        switch goal {
        case .consistency: return "Controlled cross-court dinks"
        case .serve: return "Serve reps to depth targets"
        case .returnOfServe: return "Deep return reps"
        case .dinking: return "Kitchen dink reps"
        case .thirdShotDrops: return "Third-shot drop reps"
        case .drives: return "Drive reps with depth targets"
        case .volleys: return "Punch volley reps"
        case .speedReaction: return "Reaction footwork"
        case .strategyIQ: return "Strategy sessions"
        case .competitive: return "Reaction drills"
        }
    }

    private static func prescriptionItem(_ goal: TrainingGoal, scale: Double) -> GamePlanItem {
        let title = prescriptionTitle(goal)
        switch goal {
        case .consistency:
            return GamePlanItem(title: title, amount: scaled(30, scale), unit: "reps", symbol: "target")
        case .serve:
            return GamePlanItem(title: title, amount: scaled(36, scale), unit: "reps", symbol: "hand.raised")
        case .returnOfServe:
            return GamePlanItem(title: title, amount: scaled(24, scale), unit: "reps", symbol: "arrow.uturn.left")
        case .dinking:
            return GamePlanItem(title: title, amount: scaled(30, scale), unit: "reps", symbol: "circle.grid.cross")
        case .thirdShotDrops:
            return GamePlanItem(title: title, amount: scaled(40, scale), unit: "reps", symbol: "scope")
        case .drives:
            return GamePlanItem(title: title, amount: scaled(30, scale), unit: "reps", symbol: "bolt.horizontal")
        case .volleys:
            return GamePlanItem(title: title, amount: scaled(40, scale), unit: "reps", symbol: "square.grid.3x3")
        case .speedReaction:
            return GamePlanItem(title: title, amount: scaled(10, scale), unit: "min", symbol: "hare")
        case .strategyIQ:
            return GamePlanItem(title: title, amount: 2, unit: "sessions", symbol: "brain.head.profile")
        case .competitive:
            return GamePlanItem(title: title, amount: 3, unit: "drills", symbol: "bolt.fill")
        }
    }

    /// Scales a rep count and rounds to a clean, credible number.
    private static func scaled(_ base: Int, _ scale: Double) -> Int {
        max(5, Int((Double(base) * scale / 5).rounded() * 5))
    }

    /// The single cue the coach repeats first, nudged by playing style.
    static func focusCue(for answers: OnboardingAnswers, primary: TrainingGoal) -> String {
        let softGame: Set<TrainingGoal> = [.dinking, .thirdShotDrops, .consistency]
        if answers.playerTypes.contains(.aggressive), softGame.contains(primary) {
            return "Patience first — earn the attack"
        }
        if answers.playerTypes.contains(.defensive), primary == .drives || primary == .volleys {
            return "Step in early, finish through the ball"
        }
        return focusCue(primary)
    }

    static func focusCue(_ goal: TrainingGoal) -> String {
        switch goal {
        case .consistency: return "One ball, one target — every rep has a purpose"
        case .serve: return "Same toss, same contact, every time"
        case .returnOfServe: return "Deep and through, then move in"
        case .dinking: return "Soft hands, paddle above the waist"
        case .thirdShotDrops: return "Lift with the legs, finish high"
        case .drives: return "Low to high, finish at the target"
        case .volleys: return "Punch from the shoulder, don't swing"
        case .speedReaction: return "First step explosive, stay low"
        case .strategyIQ: return "Pick your spot before the point starts"
        case .competitive: return "Play the score, not the moment"
        }
    }

    // MARK: - Wiring into the app

    /// The shot a player should practise first when they have no sessions yet.
    static func focusShot(for profile: PlayerProfile) -> ShotType {
        shot(for: curriculum(for: profile.duprRange ?? defaultRange)[0])
    }

    /// Rebuilds the onboarding answers from a saved profile.
    static func answers(from profile: PlayerProfile) -> OnboardingAnswers {
        var answers = OnboardingAnswers()
        answers.name = profile.displayName
        answers.duprRange = profile.duprRange
        answers.playerTypes = profile.playerTypes
        answers.frequency = profile.frequency
        answers.goals = profile.goals
        answers.struggles = profile.struggles
        answers.trainingTime = profile.trainingTime
        answers.successMetric = profile.successMetric
        return answers
    }

    static func shot(for goal: TrainingGoal) -> ShotType {
        switch goal {
        case .consistency, .dinking, .speedReaction: return .forehandDink
        case .serve: return .serve
        case .returnOfServe: return .returnOfServe
        case .thirdShotDrops: return .thirdShotDrop
        case .drives: return .forehandDrive
        case .volleys: return .forehandVolley
        case .strategyIQ: return .thirdShotDrop
        case .competitive: return .forehandDink
        }
    }

    static func mechanic(for goal: TrainingGoal) -> MechanicID {
        switch goal {
        case .consistency, .dinking, .returnOfServe: return .contactPosition
        case .serve: return .stanceWidth
        case .thirdShotDrops: return .weightTransfer
        case .drives: return .followThrough
        case .volleys: return .armStructure
        case .speedReaction: return .kneeBend
        case .strategyIQ, .competitive: return .contactPosition
        }
    }

    /// Picks a drill for a mechanic that suits the player's range, preferring
    /// drills at or below their level.
    static func drillID(for mechanic: MechanicID, shot: ShotType, range: DuprRange) -> String {
        let suitable = DrillLibrary.all.filter { $0.minimumLevel <= range }
        let pick = suitable.first { $0.targetMechanic == mechanic && $0.shot == shot }
            ?? suitable.first { $0.targetMechanic == mechanic && $0.shot.group == shot.group }
            ?? DrillLibrary.drill(for: mechanic, shot: shot)
        return pick?.id ?? DrillLibrary.all[0].id
    }

    /// Practice weekdays (1 = Sunday) for the player's weekly time budget.
    static func practiceWeekdays(for time: WeeklyTrainingTime) -> [Int] {
        switch time.practiceDaysPerWeek {
        case ...2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        default: return [2, 3, 4, 5, 6]
        }
    }

    /// The weekly plan. Measured weak spots (from real reps) lead; any
    /// remaining slots come from the range curriculum. With no measured data
    /// the whole week is the curriculum — the default for a brand-new player.
    /// Every week ends with a Sunday assessment so change is measured.
    ///
    /// - Parameters:
    ///   - measured: Weakest measured shot/mechanic pairs, most important first.
    ///   - leadInsight: Human-readable name of the top recurring issue, if any.
    static func weeklyPlan(profile: PlayerProfile,
                           measured: [MeasuredFocus],
                           leadInsight: String? = nil,
                           now: Date = .now) -> WeeklyPlan {
        let range = profile.duprRange ?? defaultRange
        let curriculumFocus = curriculum(for: range).map { MeasuredFocus(shot: shot(for: $0), mechanic: mechanic(for: $0)) }

        var focus: [MeasuredFocus] = []
        for item in measured.prefix(3) + curriculumFocus where !focus.contains(item) {
            focus.append(item)
        }

        var entries: [WeeklyPlan.Entry] = practiceWeekdays(for: profile.trainingTime)
            .enumerated()
            .map { index, weekday in
                let item = focus[index % focus.count]
                return WeeklyPlan.Entry(
                    weekday: weekday,
                    shot: item.shot,
                    mechanic: item.mechanic,
                    drillID: drillID(for: item.mechanic, shot: item.shot, range: range)
                )
            }

        let lead = focus[0]
        entries.append(WeeklyPlan.Entry(
            weekday: 1,
            shot: lead.shot,
            mechanic: lead.mechanic,
            drillID: DrillLibrary.drills(for: lead.shot).first?.id ?? DrillLibrary.all[0].id,
            isAssessment: true
        ))

        let rationale: String
        if let leadInsight {
            rationale = "Built around your recurring \(leadInsight) issue, measured from your reps, with the rest of the week from the \(range.rangeLabel) curriculum and a Sunday assessment to measure whether it moved."
        } else if !measured.isEmpty {
            rationale = "Built from the weakest mechanics in your recent sessions, rounded out with the \(range.rangeLabel) curriculum and a Sunday assessment to measure progress."
        } else {
            rationale = "A starter week for a \(range.fullLabel) player, ending with an assessment so Paddle Up can measure your baseline. Once you log sessions, your measured weak spots take over the plan."
        }
        return WeeklyPlan(generatedAt: now, entries: entries, rationale: rationale)
    }
}
