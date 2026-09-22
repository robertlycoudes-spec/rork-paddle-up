//
//  GamePlanEngine.swift
//  PaddleUp
//
//  Turns onboarding answers into a personalised game plan: the player's
//  biggest opportunity, a this-week prescription, and a weekly plan wired to
//  the real drill library. Deterministic and pure — the same answers always
//  produce the same plan, so the "AI result" is reproducible and testable.
//

import Foundation

/// Everything the onboarding flow collects, in order.
nonisolated struct OnboardingAnswers: Codable, Sendable, Equatable {
    var name: String = ""
    var level: SkillLevel = .intermediate
    var playerTypes: [PlayerStyle] = []
    var frequency: PlayFrequency = .weekly
    var goals: [TrainingGoal] = []
    var struggles: [BiggestStruggle] = []
    var weaknesses: [BiggestWeakness] = []
    var trainingTime: WeeklyTrainingTime = .moderate
    var motivation: TrainingMotivation?
    var competitiveness: Competitiveness?
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

/// The personalised result shown before the paywall and stored as the
/// player's active plan.
nonisolated struct GamePlan: Sendable, Equatable {
    /// e.g. "Consistency + third-shot drops"
    let opportunity: String
    /// One line explaining why that opportunity matters.
    let opportunityDetail: String
    let items: [GamePlanItem]
    /// The single cue the coach will repeat first.
    let focusCue: String
    let weeklyMinutes: Int
    let practiceDays: Int
}

nonisolated enum GamePlanEngine {

    // MARK: - Focus areas

    /// Goals ranked by priority: the named weakness leads (it is the most
    /// specific answer the player gives), then struggles (their own pain), then
    /// stated goals. Mapped onto the TrainingGoal vocabulary so the rest of the
    /// engine only deals with one taxonomy.
    static func focusAreas(for answers: OnboardingAnswers) -> [TrainingGoal] {
        let fromWeakness = answers.weaknesses.compactMap(weaknessGoal)
        let fromStruggles = answers.struggles.compactMap(struggleGoal)
        var merged: [TrainingGoal] = []
        for goal in fromWeakness + fromStruggles + answers.goals where !merged.contains(goal) {
            merged.append(goal)
        }
        return merged.isEmpty ? [.consistency] : merged
    }

    /// Weaknesses that map onto a trainable shot skill. Lob and mental game
    /// return nil and get their own dedicated plan lines instead.
    static func weaknessGoal(_ weakness: BiggestWeakness) -> TrainingGoal? {
        switch weakness {
        case .serve: return .serve
        case .returnShot: return .returnOfServe
        case .dinking: return .dinking
        case .thirdShotDrop: return .thirdShotDrops
        case .drive: return .drives
        case .volley: return .volleys
        case .footwork: return .speedReaction
        case .strategy: return .strategyIQ
        case .lob, .mentalGame: return nil
        }
    }

    /// Struggles that don't map to a shot skill (conditioning, direction)
    /// return nil and are handled as extra plan lines instead.
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

    // MARK: - The personalised result

    static func generate(_ answers: OnboardingAnswers) -> GamePlan {
        let areas = focusAreas(for: answers)
        let primary = areas[0]
        let secondary = areas.count > 1 ? areas[1] : nil

        // The named weaknesses headline the opportunity when the player gave
        // them; a single weakness is paired with the next focus area.
        var names: [String] = []
        if let first = answers.weaknesses.first {
            names.append(first.focusName)
            if let second = answers.weaknesses.dropFirst().first {
                names.append(second.focusName.lowercased())
            } else if let secondary {
                names.append(secondary.displayName.lowercased())
            }
        }
        if names.isEmpty { names = [primary.displayName] }
        let opportunity = names.joined(separator: " + ")

        let scale = answers.trainingTime.repScale
            * (answers.level == .justStarting ? 0.7 : 1.0)
            * (answers.competitiveness?.repScale ?? 1.0)

        var items: [GamePlanItem] = []
        func append(_ goal: TrainingGoal) {
            guard !items.contains(where: { $0.title == prescriptionTitle(goal) }) else { return }
            items.append(prescriptionItem(goal, scale: scale))
        }

        // Weaknesses with no shot mapping still lead the plan with their own line.
        for weakness in answers.weaknesses where weaknessGoal(weakness) == nil {
            let item = weaknessItem(weakness, scale: scale)
            if !items.contains(where: { $0.title == item.title }) {
                items.append(item)
            }
        }
        for goal in areas.prefix(3) { append(goal) }

        // Playing style acts as a counterweight so the plan rounds out the game.
        // Up to two named styles get their own balancing line, deduped by title.
        for style in answers.playerTypes.prefix(2) {
            let item = styleItem(for: style, scale: scale)
            if !items.contains(where: { $0.title == item.title }) {
                items.append(item)
            }
        }

        // Extra lines driven by the unmappable struggles.
        if answers.struggles.contains(.whatToPractice) {
            items.append(GamePlanItem(
                title: "Guided sessions with your AI coach",
                amount: 3, unit: "sessions", symbol: "waveform"
            ))
        }
        if answers.struggles.contains(.fitness) || answers.goals.contains(.speedReaction) {
            if !items.contains(where: { $0.unit == "min" }) {
                items.append(GamePlanItem(
                    title: "Footwork & conditioning",
                    amount: scaled(10, scale), unit: "min", symbol: "figure.run"
                ))
            }
        }
        if answers.goals.contains(.strategyIQ) || answers.struggles.contains(.betterPlayers) {
            if !items.contains(where: { $0.title.contains("strategy") }) {
                items.append(GamePlanItem(
                    title: "Strategy sessions",
                    amount: 2, unit: "sessions", symbol: "brain.head.profile"
                ))
            }
        }
        // Competitive players rehearse pressure, not just technique.
        if answers.competitiveness?.wantsPressureWork == true,
           !items.contains(where: { $0.title == "Scored, game-like reps" }) {
            items.append(GamePlanItem(
                title: "Scored, game-like reps",
                amount: answers.competitiveness == .tournament ? 3 : 2,
                unit: "sessions", symbol: "trophy.fill"
            ))
        }
        // Always give the plan a reaction line for competitive motivation.
        if answers.motivation == .tournaments || answers.motivation == .competitivePlayer,
           !items.contains(where: { $0.title == "Reaction drills" }) {
            items.append(GamePlanItem(
                title: "Reaction drills",
                amount: 3, unit: "drills", symbol: "bolt.fill"
            ))
        }

        // Keep the reveal glanceable — the plan adapts weekly anyway.
        let trimmed = Array(items.prefix(5))

        return GamePlan(
            opportunity: opportunity,
            opportunityDetail: detailNarrative(for: answers, primary: primary),
            items: trimmed,
            focusCue: focusCue(for: answers, primary: primary),
            weeklyMinutes: answers.trainingTime.weeklyMinutes,
            practiceDays: answers.trainingTime.practiceDaysPerWeek
        )
    }

    /// Dedicated line for a weakness that isn't a measurable shot skill yet.
    private static func weaknessItem(_ weakness: BiggestWeakness, scale: Double) -> GamePlanItem {
        switch weakness {
        case .lob:
            return GamePlanItem(title: "Overhead & lob defence reps",
                                amount: scaled(20, scale), unit: "reps", symbol: "arrow.up.right")
        case .mentalGame:
            return GamePlanItem(title: "Pressure reps — play to a score",
                                amount: 3, unit: "sessions", symbol: "brain.head.profile")
        default:
            return prescriptionItem(weaknessGoal(weakness) ?? .consistency, scale: scale)
        }
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

    /// Builds the "why this matters" paragraph out of the player's own answers:
    /// their weakness, their style, and their definition of success.
    private static func detailNarrative(for answers: OnboardingAnswers,
                                        primary: TrainingGoal) -> String {
        var sentences: [String] = []

        if !answers.weaknesses.isEmpty {
            sentences.append(contentsOf: answers.weaknesses.prefix(2).map(weaknessDetail))
        } else {
            sentences.append(opportunityDetail(primary))
        }
        if let style = answers.playerTypes.first, let clause = styleClause(style, answers: answers) {
            sentences.append(clause)
        }
        if let metric = answers.successMetric {
            sentences.append(successClause(metric, answers: answers))
        }
        return sentences.joined(separator: " ")
    }

    private static func weaknessDetail(_ weakness: BiggestWeakness) -> String {
        switch weakness {
        case .serve: return "You named your serve — the one shot nobody can rush. We'll make it repeatable before we make it bigger."
        case .returnShot: return "You named your return. A deep return buys you the kitchen, and it's the fastest gain most players skip."
        case .dinking: return "You named your dinks. Kitchen points reward patience and placement, so we'll build your soft game first."
        case .thirdShotDrop: return "You named your third-shot drop — the shot that decides whether you reach the kitchen at all."
        case .drive: return "You named your drive. Depth and shape come before pace, or the ball just comes back faster."
        case .volley: return "You named your volleys. Holding the line under pressure starts with a stable paddle and a short punch."
        case .lob: return "You named the lob. Reading it early and turning under the ball turns a scramble into an easy overhead."
        case .footwork: return "You named your footwork. Almost every technique fault is really a position fault one step earlier."
        case .strategy: return "You named strategy. Shot selection beats shot-making at every level, so we'll train your decisions."
        case .mentalGame: return "You named the mental game. We'll train it the only way it improves: scored reps where the pressure is real."
        }
    }

    private static func styleClause(_ style: PlayerStyle, answers: OnboardingAnswers) -> String? {
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

    private static func successClause(_ metric: SuccessMetric, answers: OnboardingAnswers) -> String {
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
        switch goal {
        case .consistency:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(30, scale),
                                unit: "reps", symbol: "target")
        case .serve:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(36, scale),
                                unit: "reps", symbol: "hand.raised")
        case .returnOfServe:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(24, scale),
                                unit: "reps", symbol: "arrow.uturn.left")
        case .dinking:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(30, scale),
                                unit: "reps", symbol: "circle.grid.cross")
        case .thirdShotDrops:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(40, scale),
                                unit: "reps", symbol: "scope")
        case .drives:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(30, scale),
                                unit: "reps", symbol: "bolt.horizontal")
        case .volleys:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(40, scale),
                                unit: "reps", symbol: "square.grid.3x3")
        case .speedReaction:
            return GamePlanItem(title: prescriptionTitle(goal), amount: scaled(10, scale),
                                unit: "min", symbol: "hare")
        case .strategyIQ:
            return GamePlanItem(title: prescriptionTitle(goal), amount: 2,
                                unit: "sessions", symbol: "brain.head.profile")
        case .competitive:
            return GamePlanItem(title: prescriptionTitle(goal), amount: 3,
                                unit: "drills", symbol: "bolt.fill")
        }
    }

    /// Scales a rep count and rounds to a clean, credible number.
    private static func scaled(_ base: Int, _ scale: Double) -> Int {
        max(5, Int((Double(base) * scale / 5).rounded() * 5))
    }

    private static func opportunityDetail(_ goal: TrainingGoal) -> String {
        switch goal {
        case .consistency:
            return "Unforced errors decide more amateur games than winners do. We'll tighten your contact point first."
        case .serve:
            return "The only shot you fully control. A repeatable serve starts every point on your terms."
        case .returnOfServe:
            return "A deep return buys you the kitchen. It's the fastest rating gain most players ignore."
        case .dinking:
            return "Kitchen points are won by patience and placement, not power. We'll build your soft game."
        case .thirdShotDrops:
            return "Your third shot decides whether you reach the kitchen — we'll build it rep by rep."
        case .drives:
            return "Penetrating drives create weak replies you can attack. Depth targets first."
        case .volleys:
            return "Clean volleys let you hold the line under pressure. We'll keep your shape stable."
        case .speedReaction:
            return "First-step quickness wins the tight exchanges. Short, sharp footwork blocks."
        case .strategyIQ:
            return "Shot selection beats shot-making at every level. We'll train your decisions."
        case .competitive:
            return "Competitors rehearse pressure. Your plan mixes skills with scored, game-like reps."
        }
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
        if answers.weaknesses.contains(.lob) { return "Turn and track — get behind the ball" }
        if answers.weaknesses.contains(.mentalGame) { return "One point at a time, reset between reps" }
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

    /// The shot the player should practise first, from a saved profile.
    static func focusShot(for profile: PlayerProfile) -> ShotType {
        return shot(for: focusAreas(for: answers(from: profile))[0])
    }

    /// Rebuilds the onboarding answers from a saved profile, so every feature
    /// personalises from the same inputs the plan was generated with.
    static func answers(from profile: PlayerProfile) -> OnboardingAnswers {
        var answers = OnboardingAnswers()
        answers.name = profile.displayName
        answers.level = profile.skillLevel
        answers.playerTypes = profile.playerTypes
        answers.frequency = profile.frequency
        answers.goals = profile.goals
        answers.struggles = profile.struggles
        answers.weaknesses = profile.weaknesses
        answers.trainingTime = profile.trainingTime
        answers.motivation = profile.motivation
        answers.competitiveness = profile.competitiveness
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

    /// The active weekly plan, built from onboarding answers, ending in a
    /// baseline assessment so improvement can be measured.
    static func weeklyPlan(from answers: OnboardingAnswers) -> WeeklyPlan {
        let areas = Array(focusAreas(for: answers).prefix(3))

        let daySlots: [Int]
        switch answers.trainingTime.practiceDaysPerWeek {
        case ...2: daySlots = [2, 5]
        case 3: daySlots = [2, 4, 6]
        case 4: daySlots = [2, 3, 5, 6]
        default: daySlots = [2, 3, 4, 5, 6]
        }

        var entries: [WeeklyPlan.Entry] = daySlots.enumerated().map { index, weekday in
            let goal = areas[index % areas.count]
            let shot = shot(for: goal)
            let mechanic = mechanic(for: goal)
            return WeeklyPlan.Entry(
                weekday: weekday,
                shot: shot,
                mechanic: mechanic,
                drillID: DrillLibrary.drill(for: mechanic, shot: shot)?.id ?? DrillLibrary.all[0].id
            )
        }

        let assessmentGoal = areas[0]
        let assessmentShot = shot(for: assessmentGoal)
        entries.append(WeeklyPlan.Entry(
            weekday: 1,
            shot: assessmentShot,
            mechanic: mechanic(for: assessmentGoal),
            drillID: DrillLibrary.drills(for: assessmentShot).first?.id ?? DrillLibrary.all[0].id,
            isAssessment: true
        ))

        let plan = generate(answers)
        var rationale = "Built from your onboarding: \(plan.opportunity) is your biggest opportunity, with a baseline assessment so Paddle Up can measure whether it moves."
        if !answers.playerTypes.isEmpty {
            rationale += " Balanced for a \(answers.playerTypes.prefix(2).map { $0.displayName.lowercased() }.joined(separator: " + ")) player"
            if let competitiveness = answers.competitiveness {
                rationale += " training as a \(competitiveness.displayName.lowercased())"
            }
            rationale += "."
        }
        return WeeklyPlan(generatedAt: .now, entries: entries, rationale: rationale)
    }
}
