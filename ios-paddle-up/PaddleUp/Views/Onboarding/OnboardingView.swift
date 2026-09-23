//
//  OnboardingView.swift
//  PaddleUp
//
//  The evaluation flow: ten quick questions, a staged "AI analysis", the
//  personalised game plan, and the paywall as its natural conclusion.
//  Answers are saved to the profile after every selection so nothing is lost
//  if the app is killed mid-flow.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store

    private enum Step {
        case hook, name, level, playerType, frequency, goals, struggles
        case radarGaps, radarPath
        case time, advantage, successMetric
        case analyzing, plan, paywall
    }

    private static let questionSteps: [Step] = [
        .name, .level, .playerType, .frequency, .goals, .struggles,
        .radarGaps, .radarPath, .time, .advantage, .successMetric
    ]

    /// Skill map with visible gaps — the honest baseline the destination map
    /// then promises to develop.
    private static let gapAxes: [OnboardingRadarChart.Axis] = [
        .init(label: "Dinking", value: 0.62),
        .init(label: "Drops", value: 0.45),
        .init(label: "Drives", value: 0.80),
        .init(label: "Volleys", value: 0.50),
        .init(label: "Serves", value: 0.72),
        .init(label: "Footwork", value: 0.40)
    ]

    /// The same map fully developed — the promise the plan works toward.
    private static let fullAxes: [OnboardingRadarChart.Axis] = [
        .init(label: "Dinking", value: 0.95),
        .init(label: "Drops", value: 0.90),
        .init(label: "Drives", value: 0.93),
        .init(label: "Volleys", value: 0.90),
        .init(label: "Serves", value: 0.92),
        .init(label: "Footwork", value: 0.90)
    ]

    @State private var step: Step = .hook
    @State private var slidesForward = true
    @State private var answers = OnboardingAnswers()

    // Mirrors for the single-select questions. They stay `nil` on a fresh run
    // so no option looks pre-picked and NEXT only appears after a real tap;
    // they restore from the profile for returning players.
    @State private var selectedRange: DuprRange?
    @State private var selectedFrequency: PlayFrequency?
    @State private var selectedTime: WeeklyTrainingTime?
    @State private var answeredSteps: Set<Step> = []

    private var questionIndex: Int? { Self.questionSteps.firstIndex(of: step) }

    var body: some View {
        ZStack {
            PUBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                if questionIndex != nil {
                    QuestionHeader(index: questionIndex!, total: Self.questionSteps.count) {
                        goBack()
                    }
                    .transition(.opacity)
                }

                content
                    .id(step)
                    .transition(.push(from: slidesForward ? .trailing : .leading))
            }
        }
        .onAppear(perform: hydrate)
    }

    // MARK: - Screens

    @ViewBuilder
    private var content: some View {
        switch step {
        case .hook:
            HookScreen {
                Haptics.tap()
                advance()
            }

        case .name:
            QuestionScreen(
                title: "What's your name?",
                subtitle: "Your coach uses it to personalise your sessions.",
                eyebrow: "LET'S BEGIN",
                canContinue: !answers.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onContinue: { advance() }
            ) {
                VStack(spacing: 14) {
                    NameField(text: $answers.name)
                    CoachGreetingPreview(name: answers.name)
                }
                .onChange(of: answers.name) { _, _ in
                    // Save the name as it's typed so it survives a relaunch.
                    appState.saveOnboardingDraft(answers)
                }
            }

        case .level:
            QuestionScreen(
                title: "What's your DUPR rating?",
                subtitle: "Know your DUPR? Pick the range it falls in. If not, pick the description that fits best.",
                eyebrow: "YOUR BASELINE",
                canContinue: answeredSteps.contains(.level),
                onContinue: { advance() }
            ) {
                ForEach(DuprRange.allCases) { range in
                    SelectionRow(title: "DUPR \(range.rangeLabel)  ·  \(range.displayName)",
                                 detail: range.detail,
                                 isSelected: selectedRange == range) {
                        select {
                            selectedRange = range
                            answers.duprRange = range
                        }
                    }
                    .accessibilityIdentifier("dupr-\(range.rawValue)")
                }
            }

        case .playerType:
            QuestionScreen(
                title: "What type of player are you?",
                subtitle: "Pick up to 3 — your coach balances your plan across them.",
                eyebrow: "YOUR IDENTITY",
                canContinue: !answers.playerTypes.isEmpty,
                onContinue: { advance() }
            ) {
                ForEach(PlayerStyle.allCases) { style in
                    SelectionRow(title: style.displayName, detail: nil, symbol: style.symbol,
                                 isSelected: answers.playerTypes.contains(style)) {
                        select(toggle: \.playerTypes, value: style, max: 3)
                    }
                }
            }

        case .frequency:
            QuestionScreen(
                title: "How often do you play?",
                subtitle: "Your plan fits around your court time.",
                eyebrow: "YOUR ROUTINE",
                canContinue: answeredSteps.contains(.frequency),
                onContinue: { advance() }
            ) {
                ForEach(PlayFrequency.allCases) { option in
                    SelectionRow(title: option.displayName, detail: nil,
                                 isSelected: selectedFrequency == option) {
                        select {
                            selectedFrequency = option
                            answers.frequency = option
                        }
                    }
                }
            }

        case .goals:
            QuestionScreen(
                title: "What do you want to improve most?",
                subtitle: "Pick as many as you like — your coach prioritises them.",
                eyebrow: "YOUR FOCUS",
                canContinue: !answers.goals.isEmpty,
                onContinue: { advance() }
            ) {
                ForEach(TrainingGoal.allCases) { goal in
                    SelectionRow(title: goal.displayName, detail: nil, symbol: goal.symbol,
                                 isSelected: answers.goals.contains(goal)) {
                        select(toggle: \.goals, value: goal)
                    }
                }
            }

        case .struggles:
            QuestionScreen(
                title: "What's holding your game back?",
                subtitle: "Be honest — Paddle Up verifies these against your measured reps.",
                eyebrow: "HONEST CHECK",
                canContinue: !answers.struggles.isEmpty,
                onContinue: { advance() }
            ) {
                ForEach(BiggestStruggle.allCases) { struggle in
                    SelectionRow(title: struggle.displayName, detail: nil,
                                 isSelected: answers.struggles.contains(struggle)) {
                        select(toggle: \.struggles, value: struggle)
                    }
                }
            }

        case .radarGaps:
            QuestionScreen(
                title: "Find exactly what's holding you back",
                subtitle: "Paddle Up measures every rep, so your plan targets the zones that actually cost you points.",
                eyebrow: "YOUR SKILL MAP",
                onContinue: { advance() }
            ) {
                OnboardingRadarChart(
                    axes: Self.gapAxes,
                    caption: "Your plan finds your hidden gaps and turns them into strengths.",
                    showsLegend: true
                )
            }

        case .radarPath:
            QuestionScreen(
                title: "Unlock your fastest path",
                subtitle: "Your plan trains every skill that matters — not just the ones you already like.",
                eyebrow: "THE DESTINATION",
                onContinue: { advance() }
            ) {
                OnboardingRadarChart(
                    axes: Self.fullAxes,
                    caption: "Paddle Up develops every skill area — not just your favorites."
                )
            }

        case .time:
            QuestionScreen(
                title: "How much time can you train each week?",
                subtitle: "We'll size your weekly plan to fit.",
                eyebrow: "YOUR WEEK",
                canContinue: answeredSteps.contains(.time),
                onContinue: { advance() }
            ) {
                ForEach(WeeklyTrainingTime.allCases) { option in
                    SelectionRow(title: option.displayName,
                                 detail: "\(option.practiceDaysPerWeek) practice days a week",
                                 isSelected: selectedTime == option) {
                        select {
                            selectedTime = option
                            answers.trainingTime = option
                        }
                    }
                }
            }

        case .advantage:
            QuestionScreen(
                title: "The advantage",
                subtitle: "Players who train with a structured plan improve faster than players who go it alone.",
                eyebrow: "YOUR ADVANTAGE",
                onContinue: { advance() }
            ) {
                AdvantageCard()
            }

        case .successMetric:
            QuestionScreen(
                title: "What would make you say this app is working?",
                subtitle: "Your coach measures progress the way you define it.",
                eyebrow: "THE FINISH LINE",
                canContinue: answers.successMetric != nil,
                onContinue: { advance() }
            ) {
                ForEach(SuccessMetric.allCases) { option in
                    SelectionRow(title: option.displayName, detail: nil,
                                 isSelected: answers.successMetric == option) {
                        select { answers.successMetric = option }
                    }
                }
            }

        case .analyzing:
            AnalyzingScreen(firstName: answers.name) {
                withAnimation(spring) { step = .plan }
            }

        case .plan:
            PlanScreen(plan: GamePlanEngine.generate(answers)) {
                Haptics.success()
                advance()
            }

        case .paywall:
            PaywallScreen(answers: answers) {
                appState.completeOnboarding(answers)
            }
        }
    }

    // MARK: - Selection handling

    /// Single-select tap: record, save the draft, and arm the NEXT button.
    private func select(_ apply: () -> Void) {
        Haptics.tap()
        apply()
        answeredSteps.insert(step)
        appState.saveOnboardingDraft(answers)
    }

    /// Multi-select tap: toggle the value and save. The Continue button moves
    /// the player forward once they've picked at least one.
    private func select<T: Equatable & Sendable>(
        toggle keyPath: WritableKeyPath<OnboardingAnswers, [T]>, value: T
    ) {
        Haptics.tap()
        let list = answers[keyPath: keyPath]
        if let index = list.firstIndex(of: value) {
            answers[keyPath: keyPath].remove(at: index)
        } else {
            answers[keyPath: keyPath].append(value)
        }
        appState.saveOnboardingDraft(answers)
    }

    /// Multi-select tap with a cap: toggle the value, ignoring picks beyond
    /// `max` so the player can't over-select.
    private func select<T: Equatable & Sendable>(
        toggle keyPath: WritableKeyPath<OnboardingAnswers, [T]>, value: T, max maximum: Int
    ) {
        Haptics.tap()
        let list = answers[keyPath: keyPath]
        if let index = list.firstIndex(of: value) {
            answers[keyPath: keyPath].remove(at: index)
        } else {
            guard list.count < maximum else { return }
            answers[keyPath: keyPath].append(value)
        }
        appState.saveOnboardingDraft(answers)
    }

    private var spring: Animation { .spring(response: 0.42, dampingFraction: 0.86) }

    private func advance() {
        let next: Step? = switch step {
        case .hook: .name
        case .name: .level
        case .level: .playerType
        case .playerType: .frequency
        case .frequency: .goals
        case .goals: .struggles
        case .struggles: .radarGaps
        case .radarGaps: .radarPath
        case .radarPath: .time
        case .time: .advantage
        case .advantage: .successMetric
        case .successMetric: .analyzing
        case .analyzing: nil // the analyzing screen advances itself
        case .plan: .paywall
        case .paywall: nil // completion routes out of onboarding
        }
        guard let next else { return }
        slidesForward = true
        withAnimation(spring) { step = next }
    }

    private func goBack() {
        guard let index = questionIndex, index > 0 else {
            slidesForward = false
            withAnimation(spring) { step = .hook }
            return
        }
        slidesForward = false
        withAnimation(spring) { step = Self.questionSteps[index - 1] }
    }

    /// Restores a partially-completed flow so answers survive a relaunch.
    /// Single-select mirrors only restore for established profiles; a fresh
    /// run starts clean so nothing looks pre-picked.
    private func hydrate() {
        let profile = appState.profile
        answers.name = profile.displayName
        answers.playerTypes = profile.playerTypes
        answers.goals = profile.goals
        answers.struggles = profile.struggles
        answers.successMetric = profile.successMetric

        if profile.hasCompletedOnboarding || profile.duprRange != nil {
            selectedRange = profile.duprRange
            answers.duprRange = profile.duprRange
            if profile.duprRange != nil { answeredSteps.insert(.level) }
        }
        if profile.hasCompletedOnboarding {
            selectedFrequency = profile.frequency
            selectedTime = profile.trainingTime
            answers.frequency = profile.frequency
            answers.trainingTime = profile.trainingTime
            answeredSteps.formUnion([.name, .frequency, .time])
        }
    }
}

// MARK: - Header

private struct QuestionHeader: View {
    let index: Int
    let total: Int
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PUColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(PUColor.surface, in: .circle)
                        .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))
                }
                .buttonStyle(RowPressStyle())
                .accessibilityLabel("Back")

                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { segment in
                        Capsule()
                            .fill(segment <= index ? PUColor.lime : Color.white.opacity(0.09))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }

                Text("\(index + 1)/\(total)")
                    .font(PUFont.micro.monospacedDigit())
                    .foregroundStyle(PUColor.textTertiary)
            }
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.3), value: index)
    }
}

// MARK: - Question scaffold

private struct QuestionScreen<Options: View>: View {
    let title: String
    let subtitle: String
    var eyebrow: String?
    var canContinue: Bool = true
    let onContinue: () -> Void
    @ViewBuilder var options: Options

    @State private var appeared = false

    init(
        title: String,
        subtitle: String,
        eyebrow: String? = nil,
        canContinue: Bool = true,
        onContinue: @escaping () -> Void = {},
        @ViewBuilder options: () -> Options
    ) {
        self.title = title
        self.subtitle = subtitle
        self.eyebrow = eyebrow
        self.canContinue = canContinue
        self.onContinue = onContinue
        self.options = options()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let eyebrow {
                            HStack(spacing: 10) {
                                Capsule()
                                    .fill(PUColor.lime)
                                    .frame(width: 16, height: 2)
                                Text(eyebrow)
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(2)
                                    .foregroundStyle(PUColor.lime)
                                Capsule()
                                    .fill(PUColor.hairline)
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        Text(title)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(PUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(PUFont.body)
                            .foregroundStyle(PUColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.85).delay(0.05),
                        value: appeared
                    )

                    VStack(spacing: 10) {
                        options
                    }
                    .padding(.bottom, 110)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.85).delay(0.16),
                        value: appeared
                    )
                }
                .padding(.horizontal, PUMetrics.margin)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05)) {
                    appeared = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.tap()
                onContinue()
            } label: {
                HStack(spacing: 9) {
                    Text("NEXT")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                }
            }
            .buttonStyle(PUPrimaryButtonStyle(enabled: canContinue))
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0)
            .offset(y: canContinue ? 0 : 12)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: canContinue)
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .animation(nil, value: canContinue)
        }
    }
}

// MARK: - Screen 1 · Hook

/// Opening slide: hero brand card with a stat strip, then four numbered
/// promise rows. Sets the premium tone before the first question.
private struct HookScreen: View {
    let onStart: () -> Void
    @State private var appeared = false
    @State private var unlocked = false
    @State private var unlockPulse = false
    @State private var hintBounces = false
    @State private var scrollProgress: Double = 0

    /// The four promises, in order. Copy sticks to what the app actually does —
    /// plan building, strategy, rep scoring, and the voice coach.
    private let promises: [(index: String, symbol: String, title: String, detail: String)] = [
        ("01", "target",
         "Daily training, built for you",
         "Drills that attack your weak spots — chosen from your own answers."),
        ("02", "brain.head.profile",
         "Think the game",
         "Court-craft lessons pulled from real pickleball situations."),
        ("03", "camera.viewfinder",
         "Every rep, scored",
         "Your camera spots each rep hands-free and scores its mechanics 1–100."),
        ("04", "waveform",
         "Your AI coach, 24/7",
         "One fix at a time, spoken between reps — tuned to your game.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    header
                        .padding(.top, 12)

                    HeroCard()
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .offset(y: appeared ? 0 : 22)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05),
                                   value: appeared)

                    ForEach(Array(promises.enumerated()), id: \.offset) { index, promise in
                        promiseRow(index: index, promise: promise)
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, PUMetrics.margin)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Double.self) { geometry in
                // Reading progress 0…1 for the header stub; 1 when the content
                // fits without scrolling.
                let maxScroll = geometry.contentSize.height
                    + geometry.contentInsets.top
                    + geometry.contentInsets.bottom
                    - geometry.containerSize.height
                guard maxScroll > 40 else { return 1 }
                let position = geometry.contentOffset.y + geometry.contentInsets.top
                return min(1, max(0, position / maxScroll))
            } action: { _, progress in
                scrollProgress = progress
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if !unlocked {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .offset(y: hintBounces ? 2 : -1)
                        Text("Scroll to meet your coach")
                            .font(PUFont.micro)
                            .textCase(.uppercase)
                            .tracking(1.1)
                    }
                    .foregroundStyle(PUColor.textTertiary)
                    .transition(.opacity)
                    .animation(
                        .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                        value: hintBounces
                    )
                }

                Button {
                    Haptics.tap()
                    onStart()
                } label: {
                    HStack(spacing: 9) {
                        Text("CONTINUE")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .heavy))
                    }
                }
                .buttonStyle(PUPrimaryButtonStyle(enabled: unlocked))
                .disabled(!unlocked)
                .overlay(
                    // One-shot expanding ring the moment CONTINUE unlocks.
                    Capsule()
                        .strokeBorder(PUColor.lime.opacity(unlockPulse ? 0 : 0.55), lineWidth: 2)
                        .scaleEffect(unlockPulse ? 1.14 : 0.94)
                        .allowsHitTesting(false)
                )
                .onChange(of: unlocked) { _, isUnlocked in
                    guard isUnlocked else { return }
                    withAnimation(.easeOut(duration: 0.9)) { unlockPulse = true }
                }
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: unlocked)
        }
        .onAppear {
            appeared = true
            hintBounces = true
        }
    }

    /// Staggered entrance row; the final coach promise carries the unlock
    /// trigger, so CONTINUE enables the moment it's half on screen.
    @ViewBuilder
    private func promiseRow(
        index: Int, promise: (index: String, symbol: String, title: String, detail: String)
    ) -> some View {
        let row = PromiseRow(index: promise.index, symbol: promise.symbol,
                             title: promise.title, detail: promise.detail)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.85)
                    .delay(0.15 + Double(index) * 0.07),
                value: appeared
            )
        if index == promises.count - 1 {
            row.onScrollVisibilityChange(threshold: 0.5) { isVisible in
                withAnimation(.easeOut(duration: 0.3)) { unlocked = isVisible }
            }
        } else {
            row
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("GETTING STARTED")
                .font(.system(size: 12, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(PUColor.textPrimary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09))
                    Capsule()
                        .fill(PUColor.lime)
                        .frame(width: appeared ? geo.size.width * max(0.12, scrollProgress) : 0)
                        .animation(.easeOut(duration: 0.25), value: scrollProgress)
                }
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)
        }
    }
}

/// The hero brand card: glyph in a dashed orbit ring, wordmark, system tagline,
/// pitch copy, and a hairline-divided three-up stat strip.
private struct HeroCard: View {
    @State private var orbits = false
    @State private var livePulse = false
    @State private var statsIn = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                glyph

                VStack(spacing: 10) {
                    Text("PADDLE UP")
                        .font(.system(size: 30, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(PUColor.textPrimary)
                    Capsule()
                        .fill(PUColor.lime)
                        .frame(width: 26, height: 3)
                    Text("AI PICKLEBALL DEVELOPMENT SYSTEM")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(PUColor.lime)
                }

                liveChip

                Text("Your coach builds the plan, reads your game, and pushes you every single day. All you have to do is show up.")
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 22)

            Rectangle().fill(PUColor.hairline).frame(height: 1)

            HStack(spacing: 0) {
                stat(value: "Daily", label: "NEW PLAN", delay: 0.55)
                Rectangle().fill(PUColor.hairline).frame(width: 1, height: 40)
                stat(value: "24/7", label: "AI COACH", delay: 0.65)
                Rectangle().fill(PUColor.hairline).frame(width: 1, height: 40)
                stat(value: "100%", label: "BUILT FOR YOU", delay: 0.75)
            }
            .padding(.vertical, 14)
        }
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
        .onAppear {
            orbits = true
            livePulse = true
            statsIn = true
        }
    }

    /// Ball glyph inside a raised disc, wrapped in two counter-rotating
    /// dashed rings, each carrying a satellite dot, over a faint lime bloom —
    /// the "live coach" motif. Every ring rotates alone around its own
    /// centre; dots stay pinned so nothing wobbles.
    private var glyph: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PUColor.lime.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 66
                    )
                )
                .frame(width: 132, height: 132)

            Circle()
                .stroke(PUColor.lime.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                .frame(width: 104, height: 104)
                .rotationEffect(.degrees(orbits ? 360 : 0))
                .animation(.linear(duration: 48).repeatForever(autoreverses: false), value: orbits)

            Circle()
                .stroke(PUColor.lime.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [1, 6]))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(orbits ? -360 : 0))
                .animation(.linear(duration: 36).repeatForever(autoreverses: false), value: orbits)

            Circle()
                .fill(PUColor.lime)
                .frame(width: 7, height: 7)
                .offset(x: -52, y: 0)

            Circle()
                .fill(PUColor.lime.opacity(0.5))
                .frame(width: 4, height: 4)
                .offset(x: 44, y: 0)

            Circle()
                .fill(PUColor.surfaceRaised)
                .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))
                .frame(width: 72, height: 72)

            // Symmetric mark, no offset maths: rings, disc and ball share
            // one centre inside a square frame.
            PUBallMark(size: 40)
        }
        .frame(width: 132, height: 132)
        .onAppear { orbits = true }
    }

    /// Pulsing status chip — the hook's second (and only other) ambient
    /// animation, selling the "live coach" from the first second.
    private var liveChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(PUColor.lime)
                .frame(width: 5, height: 5)
                .opacity(livePulse ? 1 : 0.25)
            Text("SYSTEM ONLINE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PUColor.lime)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PUColor.lime.opacity(0.08), in: .capsule)
        .overlay(Capsule().strokeBorder(PUColor.lime.opacity(0.22), lineWidth: 1))
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: livePulse)
    }

    private func stat(value: String, label: String, delay: Double) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(PUColor.textPrimary)
                .opacity(statsIn ? 1 : 0)
                .offset(y: statsIn ? 0 : 8)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PUColor.textTertiary)
                .opacity(statsIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(delay), value: statsIn)
    }
}

/// A numbered promise row under the hero card.
private struct PromiseRow: View {
    let index: String
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            PUIconBadge(symbol: symbol, size: 44)
                .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PUFont.headline)
                    .foregroundStyle(PUColor.textPrimary)
                Text(detail)
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(index)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(PUColor.lime.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
    }
}

/// "The advantage" story slide: a flat two-bar comparison — going it alone
/// vs structured training with Paddle Up. The lime 2X bar is the only thing
/// that animates, growing upward from the baseline; no gradients, just
/// surface, hairlines and one lime fill.
private struct AdvantageCard: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 28) {
                bar(label: "GOING IT ALONE", value: "20%",
                    barHeight: 104, fill: PUColor.surfaceRaised,
                    valueColor: PUColor.textPrimary, isAnimated: false)
                bar(label: "WITH PADDLE UP", value: "2X",
                    barHeight: 216, fill: PUColor.lime,
                    valueColor: PUColor.limeInk, isAnimated: true)
            }
            .frame(maxWidth: .infinity)

            Text("Paddle Up keeps you consistent and accelerates your development.")
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) {
                appeared = true
            }
        }
    }

    /// One comparison column: micro label over a bar that sits on a shared
    /// baseline. Bars are held in a fixed-height container anchored to the
    /// bottom so growth always reads upward. Only `isAnimated` bars grow;
    /// static bars render at full height immediately.
    private func bar(label: String, value: String, barHeight: CGFloat,
                     fill: Color, valueColor: Color, isAnimated: Bool) -> some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PUColor.textTertiary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(fill == PUColor.lime ? Color.clear : PUColor.hairline,
                                          lineWidth: 1)
                    )
                    .frame(width: 104,
                           height: isAnimated
                           ? max(8, barHeight * (appeared ? 1 : 0.02)) : barHeight)
                    .overlay(alignment: .bottom) {
                        Text(value)
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(valueColor)
                            .padding(.bottom, 14)
                            .opacity(isAnimated ? (appeared ? 1 : 0) : 1)
                            .animation(.easeOut(duration: 0.35).delay(1.4), value: appeared)
                    }
                    .animation(.spring(response: 1.2, dampingFraction: 0.85).delay(0.25),
                               value: appeared)
            }
            .frame(height: 216, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Brand glyph with slow breathing rings — the app's "live coach" motif.
struct BallRings: View {
    var pulse: Bool

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(PUColor.lime.opacity(0.22), lineWidth: 1)
                    .frame(width: 108 + CGFloat(ring) * 34, height: 108 + CGFloat(ring) * 34)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                    .opacity(pulse ? 0.35 : 0.7)
                    .animation(
                        .easeInOut(duration: 1.9 + Double(ring) * 0.35)
                        .repeatForever(autoreverses: true)
                        .delay(Double(ring) * 0.25),
                        value: pulse
                    )
            }
            PUBallMark(size: 52)
                .scaleEffect(pulse ? 1.0 : 0.82)
        }
    }
}

// MARK: - Screen 8 · Personalization

private struct AnalyzingScreen: View {
    let firstName: String
    let onDone: () -> Void

    @State private var completed = 0
    @State private var isBuilding = false
    @State private var isReady = false

    /// Falls back to neutral "your" copy when the player skipped their name.
    private var displayName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        if displayName.isEmpty {
            return isReady ? "Your plan is ready." : "Creating your plan…"
        }
        return isReady ? "\(displayName)'s plan is ready."
                       : "Creating \(displayName)'s plan…"
    }

    private let stages: [(symbol: String, label: String)] = [
        ("scope", "Reading your game profile"),
        ("chart.bar.fill", "Comparing against benchmark ranges"),
        ("figure.run", "Mapping your movement priorities"),
        ("square.stack.3d.up.fill", "Selecting drills for your level"),
        ("calendar", "Sequencing your first week")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            BallRings(pulse: true)
                .padding(.bottom, 34)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PUColor.textPrimary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: isBuilding)
                    .animation(.easeInOut(duration: 0.4), value: isReady)
                Text("Your AI coach is turning your answers into a plan")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                    HStack(spacing: 12) {
                        if index < completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PUColor.limeInk)
                                .frame(width: 22, height: 22)
                                .background(PUColor.lime, in: .circle)
                        } else if index == completed {
                            ProgressView()
                                .tint(PUColor.lime)
                                .frame(width: 22, height: 22)
                        } else {
                            Image(systemName: stage.symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PUColor.textTertiary)
                                .frame(width: 22, height: 22)
                        }

                        Text(stage.label)
                            .font(PUFont.body)
                            .foregroundStyle(index <= completed
                                             ? PUColor.textPrimary : PUColor.textTertiary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .opacity(index <= completed ? 1 : 0.45)
                    .offset(y: index <= completed ? 0 : 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: 330)
            .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                    .strokeBorder(PUColor.hairline, lineWidth: 1)
            )
            .padding(.top, 30)
            Spacer()
        }
        .padding(.horizontal, PUMetrics.margin)
        .task {
            // Staged reveal so the analysis feels like real work, not a spinner.
            for index in 0..<stages.count {
                try? await Task.sleep(for: .milliseconds(index == 2 ? 700 : 560))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    completed = index + 1
                }
                Haptics.tap()
                if index == 1 {
                    withAnimation(.easeInOut(duration: 0.4)) { isBuilding = true }
                }
            }
            // Once every stage lands, flip to the personalized ready line and
            // hold it for a beat before the plan slides in.
            withAnimation(.easeInOut(duration: 0.4)) { isReady = true }
            try? await Task.sleep(for: .milliseconds(1000))
            onDone()
        }
    }
}

// MARK: - Screen 9 · Personalized result

private struct PlanScreen: View {
    let plan: GamePlan
    let onContinue: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your game plan")
                        .puMicroLabel()
                        .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your biggest opportunity:")
                            .font(PUFont.headline)
                            .foregroundStyle(PUColor.textSecondary)
                        Text(plan.opportunity)
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(PUColor.lime)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(plan.opportunityDetail)
                            .font(PUFont.body)
                            .foregroundStyle(PUColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Text("This week").puMicroLabel()
                        Spacer()
                        Text("\(plan.practiceDays) days · ~\(plan.weeklyMinutes) min")
                            .font(PUFont.micro.monospacedDigit())
                            .foregroundStyle(PUColor.textTertiary)
                    }
                    .padding(.top, 6)

                    VStack(spacing: 0) {
                        ForEach(Array(plan.items.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 14) {
                                PUIconBadge(symbol: item.symbol, size: 38)
                                Text(item.title)
                                    .font(PUFont.headline)
                                    .foregroundStyle(PUColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                (Text("\(item.amount)")
                                    .font(.system(size: 22, weight: .heavy).monospacedDigit())
                                 + Text(" \(item.unit)")
                                    .font(PUFont.micro))
                                    .foregroundStyle(PUColor.textPrimary)
                            }
                            .padding(.vertical, 12)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.85)
                                    .delay(0.3 + Double(index) * 0.13),
                                value: appeared
                            )

                            if index < plan.items.count - 1 {
                                Rectangle().fill(PUColor.hairline).frame(height: 1)
                                    .opacity(appeared ? 1 : 0)
                                    .animation(.easeOut(duration: 0.3).delay(0.3 + Double(index) * 0.13), value: appeared)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                            .strokeBorder(PUColor.hairline, lineWidth: 1)
                    )

                    Text("Your AI coach continuously adapts this plan based on your goals and measured progress — every rep sharpens it.")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 110)
                }
                .padding(.horizontal, PUMetrics.margin)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("SEE MY FULL PLAN") { onContinue() }
                .buttonStyle(PUPrimaryButtonStyle())
                .padding(.horizontal, PUMetrics.margin)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
        }
        .onAppear {
            // Stagger the reveal: the plan assembles in front of the player.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }
}

// MARK: - Screen 10 · Paywall

private struct PaywallScreen: View {
    @Environment(StoreService.self) private var store
    @Environment(AppState.self) private var appState

    let answers: OnboardingAnswers
    let onComplete: () -> Void

    @State private var selectedProductID: String = PricingConfiguration.annual.id
    @State private var message: String?

    private var selectedProduct: SubscriptionProduct {
        store.products.first { $0.id == selectedProductID } ?? PricingConfiguration.annual
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    PUBallGlyph(size: 40)
                        .padding(.top, 20)

                    VStack(spacing: 10) {
                        Text("Your personalized game plan is ready.")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(PUColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Get unlimited access to your AI pickleball coach, personalized training plans, drills, strategy, and game improvement tools.")
                            .font(PUFont.body)
                            .foregroundStyle(PUColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    PUCard {
                        VStack(alignment: .leading, spacing: 13) {
                            ForEach(ProFeature.allCases) { feature in
                                HStack(spacing: 12) {
                                    Image(systemName: feature.symbol)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(PUColor.lime)
                                        .frame(width: 22)
                                    Text(feature.title)
                                        .font(PUFont.body)
                                        .foregroundStyle(PUColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        ForEach(store.products) { product in
                            ProductRow(product: product,
                                       isSelected: selectedProductID == product.id) {
                                Haptics.tap()
                                selectedProductID = product.id
                            }
                        }
                    }

                    if let message {
                        Text(message)
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.amber)
                            .multilineTextAlignment(.center)
                    }

                    Text("Subscriptions renew automatically until cancelled. Manage or cancel any time in your Apple Account settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(PUColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, PUMetrics.margin)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    purchase()
                } label: {
                    if store.isPurchasing {
                        ProgressView().tint(PUColor.limeInk)
                    } else {
                        Text("START TRAINING — \(selectedProduct.price)")
                    }
                }
                .buttonStyle(PUPrimaryButtonStyle())
                .disabled(store.isPurchasing)

                Button("Continue with limited access") {
                    Haptics.tap()
                    onComplete()
                }
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear { appState.analytics.record(.paywallViewed) }
    }

    private func purchase() {
        Task {
            let success = await store.purchase(selectedProduct)
            if success {
                appState.analytics.record(.subscriptionStarted,
                                          properties: ["product": selectedProduct.id])
                Haptics.success()
                onComplete()
            } else {
                message = store.lastError ?? "Purchase didn't complete."
            }
        }
    }
}

private struct ProductRow: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? PUColor.lime : PUColor.textTertiary.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product.title)
                            .font(PUFont.headline)
                            .foregroundStyle(PUColor.textPrimary)
                        if let badge = product.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(PUColor.limeInk)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PUColor.lime, in: .capsule)
                        }
                    }
                    if let subtitle = product.subtitle {
                        Text(subtitle)
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.price)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PUColor.textPrimary)
                    Text(product.monthlyEquivalent ?? product.period)
                        .font(.system(size: 11))
                        .foregroundStyle(PUColor.textTertiary)
                }
            }
            .padding(16)
            .background(isSelected ? PUColor.surfaceRaised : PUColor.surface,
                        in: .rect(cornerRadius: PUMetrics.tileRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                    .strokeBorder(isSelected ? PUColor.lime.opacity(0.55) : PUColor.hairline,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option rows

struct SelectionRow: View {
    let title: String
    var detail: String?
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? PUColor.lime : PUColor.textTertiary)
                        .frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PUFont.headline)
                        .foregroundStyle(PUColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? PUColor.lime : PUColor.textTertiary.opacity(0.5),
                                      lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(PUColor.lime)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(PUColor.limeInk)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? PUColor.surfaceRaised : PUColor.surface,
                        in: .rect(cornerRadius: PUMetrics.tileRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                    .strokeBorder(isSelected ? PUColor.lime.opacity(0.55) : PUColor.hairline,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(RowPressStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelected)
    }
}

/// Subtle press-in feedback shared by all onboarding rows.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Premium name entry: an elevated card with a micro label, a large field and
/// a live validation check. Focuses itself once the slide transition settles
/// so the keyboard is ready.
private struct NameField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    private var hasName: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("First name")
                    .puMicroLabel()
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PUColor.limeInk)
                    .frame(width: 20, height: 20)
                    .background(PUColor.lime, in: .circle)
                    .scaleEffect(hasName ? 1 : 0.3)
                    .opacity(hasName ? 1 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: hasName)
            }
            .padding(.horizontal, 18)
            .padding(.top, 15)

            TextField("Type your first name", text: $text)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(PUColor.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isFocused)
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 17)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .strokeBorder(
                    isFocused ? PUColor.lime.opacity(0.55) : PUColor.hairline,
                    lineWidth: 1
                )
        )
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { isFocused = true }
        }
    }
}

/// Live preview of the coach greeting — makes the name's purpose tangible
/// while the player types. Echoes the hook's dashed-orbit motif.
private struct CoachGreetingPreview: View {
    let name: String

    private var firstName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 14) {
            PUIconBadge(symbol: "waveform", size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your coach will say")
                    .puMicroLabel()
                Group {
                    if firstName.isEmpty {
                        Text("\u{201C}Let's get to work.\u{201D}")
                            .foregroundStyle(PUColor.textTertiary)
                    } else {
                        Text("\u{201C}Let's get to work, \(firstName).\u{201D}")
                            .foregroundStyle(PUColor.textPrimary)
                    }
                }
                .font(PUFont.headline)
                .contentTransition(.opacity)
            }

            Spacer(minLength: 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                .stroke(PUColor.hairline,
                        style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
        )
        .animation(.easeInOut(duration: 0.25), value: firstName)
    }
}
