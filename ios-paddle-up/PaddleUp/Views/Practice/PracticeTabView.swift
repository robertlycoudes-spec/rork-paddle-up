//
//  PracticeTabView.swift
//  PaddleUp
//
//  Shot selection → drill selection → session length, then into camera setup.
//

import SwiftUI

struct PracticeTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router
    @Environment(StoreService.self) private var store

    @State private var selectedShot: ShotType = .forehandDink

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    if !appState.profile.hasCompletedBaselineAssessment {
                        baselineCard
                    }
                    shotSection
                    drillSection
                }
                .padding(.horizontal, PUMetrics.margin)
                .padding(.bottom, 28)
            }
            .puScreenBackground()
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(PUColor.canvas, for: .navigationBar)
            .navigationDestination(for: ShotType.self) { shot in
                DrillSelectionView(shot: shot)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .drill(let id):
                    if let drill = DrillLibrary.drill(id: id) { DrillDetailView(drill: drill) }
                case .shot(let group):
                    ShotDetailView(group: group)
                }
            }
            .navigationDestination(for: SummaryRoute.self) { route in
                switch route {
                case .mechanic(let mechanic, let group):
                    MechanicDetailView(mechanic: mechanic, group: group)
                case .rep:
                    EmptyView()
                }
            }
        }
    }

    private var intro: some View {
        Text("Pick a shot, pick a drill, prop your phone up. Paddle Up counts and scores every rep automatically.")
            .font(PUFont.body)
            .foregroundStyle(PUColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var baselineCard: some View {
        PUCard(background: PUColor.limeDim) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    PUIconBadge(symbol: "figure.pickleball")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Start here").puMicroLabel()
                        Text("Baseline Dink Assessment")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PUColor.textPrimary)
                    }
                }
                Text("20–30 dinks so Paddle Up can measure your starting point and find your weakest mechanic.")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("START ASSESSMENT") {
                    start(shot: .forehandDink, mode: .assessment, drillID: nil, length: .tenMinutes)
                }
                .buttonStyle(PUPrimaryButtonStyle())
            }
        }
    }

    private var shotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Choose a shot", accessory: "\(ShotType.practiceable.count) available")
            VStack(spacing: 10) {
                ForEach(ShotType.practiceable) { shot in
                    NavigationLink(value: shot) {
                        ShotRow(shot: shot, rating: rating(for: shot.group))
                    }
                    .buttonStyle(.plain)
                }
            }
            plannedShots
        }
    }

    private var plannedShots: some View {
        let planned = ShotType.allCases.filter { $0.analyzerStatus == .planned }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Analyzers in development").puMicroLabel().padding(.top, 8)
            FlowChips(items: planned.map(\.displayName))
            Text("These shots already have rubrics and progress tracking. Their live analyzers land after Dink is fully tuned.")
                .font(.system(size: 12))
                .foregroundStyle(PUColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var drillSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Prescribed for you")
            if let drill = appState.recommendedDrill {
                NavigationLink(value: HomeRoute.drill(drill.id)) {
                    PUCard {
                        HStack(spacing: 14) {
                            DrillThumbnail(mechanic: drill.targetMechanic)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(drill.name)
                                    .font(PUFont.headline)
                                    .foregroundStyle(PUColor.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text("Targets \(drill.targetMechanic.displayName) · \(drill.prescription)")
                                    .font(PUFont.caption)
                                    .foregroundStyle(PUColor.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PUColor.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            NavigationLink {
                WeeklyPlanView()
            } label: {
                PUCard {
                    HStack(spacing: 14) {
                        PUIconBadge(symbol: "calendar")
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Weekly practice plan")
                                .font(PUFont.headline)
                                .foregroundStyle(PUColor.textPrimary)
                            Text(appState.weeklyPlan.map { "\($0.entries.count) sessions this week" }
                                 ?? "Generate a plan from your weaknesses")
                                .font(PUFont.caption)
                                .foregroundStyle(PUColor.textSecondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PUColor.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func rating(for group: ShotGroup) -> Double? {
        appState.shotRatings.first { $0.group == group }?.score
    }

    private func start(shot: ShotType, mode: SessionMode, drillID: String?, length: SessionLength) {
        guard store.canStartSession(completedSessions: appState.completedSessionCount) else {
            router.showsPaywall = true
            return
        }
        router.startPractice(PracticeConfiguration(shot: shot, mode: mode, drillID: drillID, length: length))
    }
}

struct ShotRow: View {
    let shot: ShotType
    let rating: Double?

    var body: some View {
        HStack(spacing: 14) {
            PUIconBadge(symbol: shot.group.symbol, tint: PUColor.lime, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(shot.displayName)
                        .font(PUFont.headline)
                        .foregroundStyle(PUColor.textPrimary)
                    AnalyzerBadge(status: shot.analyzerStatus)
                }
                Text(shot.summary)
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let rating {
                Text("\(Int(rating))")
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(PUColor.score(rating))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PUColor.textTertiary)
        }
        .padding(14)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
    }
}

struct AnalyzerBadge: View {
    let status: AnalyzerStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: .capsule)
    }

    private var tint: Color {
        switch status {
        case .production: return PUColor.lime
        case .preview: return PUColor.amber
        case .planned: return PUColor.textTertiary
        }
    }
}

/// Simple wrapping chip layout.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PUColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(PUColor.surface, in: .capsule)
                    .overlay(Capsule().strokeBorder(PUColor.hairline, lineWidth: 1))
            }
        }
    }
}
