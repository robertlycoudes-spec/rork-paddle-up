//
//  HomeView.swift
//  PaddleUp
//
//  The Rating Hero home: dominant rating dial, recommended drill, a tight
//  stat row, and a single Start Practice action inset above the tab bar.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router
    @Environment(StoreService.self) private var store
    @Binding var selection: MainTabView.Tab

    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    dial
                    if let drill = appState.recommendedDrill {
                        recommendedDrillCard(drill)
                    }
                    statRow
                    if let insight = appState.recurringWeaknesses.first {
                        recurringWeaknessCard(insight)
                    }
                    if !appState.achievements.isEmpty {
                        achievementStrip
                    }
                }
                .padding(.horizontal, PUMetrics.margin)
                .padding(.bottom, 24)
            }
            .puScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
            .safeAreaInset(edge: .bottom) { startButton }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            PUWordmark()
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PUColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(PUColor.surface, in: .circle)
                    .overlay(Circle().strokeBorder(PUColor.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var dial: some View {
        PUScoreDial(
            value: appState.overallRating,
            caption: "Paddle Up Rating",
            subtitle: ratingSubtitle,
            subtitleIsPositive: (appState.overallRatingDelta ?? 0) > 0,
            size: 250
        )
        .padding(.vertical, 4)
    }

    private var ratingSubtitle: String {
        if let delta = appState.overallRatingDelta, abs(delta) >= 0.5 {
            let sign = delta > 0 ? "+" : ""
            return "\(sign)\(Int(delta.rounded())) this month"
        }
        if appState.overallRating == nil { return "Practise to get rated" }
        return "\(appState.totalRepCount) reps measured"
    }

    private func recommendedDrillCard(_ drill: Drill) -> some View {
        NavigationLink(value: HomeRoute.drill(drill.id)) {
            PUCard {
                HStack(spacing: 14) {
                    DrillThumbnail(mechanic: drill.targetMechanic)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's recommended drill").puMicroLabel()
                        Text(drill.name)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(PUColor.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(drill.prescription)
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PUColor.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var statRow: some View {
        HStack(spacing: PUMetrics.gutter) {
            PUStatTile(
                symbol: "scope",
                symbolColor: PUColor.alert,
                label: "Weakest shot",
                value: appState.weakestShot?.group.displayName ?? "—",
                detail: appState.weakestShot.map { "· \(Int($0.score))" },
                detailIsPositive: false
            )
            PUStatTile(
                symbol: "chart.bar.fill",
                symbolColor: PUColor.lime,
                label: "Recent improvement",
                value: appState.biggestImprovement?.mechanic.displayName ?? "—",
                detail: appState.biggestImprovement.map { "+\(Int($0.delta)) this month" }
            )
            PUStatTile(
                symbol: "flame.fill",
                symbolColor: PUColor.amber,
                label: "Practice streak",
                value: appState.practiceStreak > 0 ? "\(appState.practiceStreak)-day" : "Start one",
                detail: appState.practiceStreak > 0 ? "streak" : nil,
                detailIsPositive: true
            )
        }
    }

    private func recurringWeaknessCard(_ insight: WeaknessInsight) -> some View {
        PUCard(background: PUColor.limeDim) {
            HStack(alignment: .top, spacing: 12) {
                PUIconBadge(symbol: "lightbulb.fill")
                VStack(alignment: .leading, spacing: 5) {
                    Text("Pattern spotted").puMicroLabel()
                    Text(insight.message)
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var achievementStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Milestones")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(appState.achievements.prefix(6)) { achievement in
                        HStack(spacing: 9) {
                            Image(systemName: achievement.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PUColor.lime)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(achievement.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PUColor.textPrimary)
                                Text(achievement.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PUColor.textSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(PUColor.surface, in: .capsule)
                        .overlay(Capsule().strokeBorder(PUColor.hairline, lineWidth: 1))
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var startButton: some View {
        Button {
            Haptics.tap()
            selection = .practice
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("START PRACTICE")
            }
        }
        .buttonStyle(PUPrimaryButtonStyle())
        .padding(.horizontal, PUMetrics.margin)
        .padding(.bottom, 8)
    }
}

nonisolated enum HomeRoute: Hashable {
    case drill(String)
    case shot(ShotGroup)
}

/// Abstract court-trajectory thumbnail used on drill cards.
struct DrillThumbnail: View {
    let mechanic: MechanicID

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(puHex(0x10200E))
            Canvas { context, size in
                // Court grid
                var grid = Path()
                grid.move(to: CGPoint(x: 0, y: size.height * 0.62))
                grid.addLine(to: CGPoint(x: size.width, y: size.height * 0.62))
                grid.move(to: CGPoint(x: size.width * 0.5, y: 0))
                grid.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
                context.stroke(grid, with: .color(PUColor.lime.opacity(0.18)), lineWidth: 1)

                // Ball arc
                var arc = Path()
                arc.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.72))
                arc.addQuadCurve(
                    to: CGPoint(x: size.width * 0.82, y: size.height * 0.56),
                    control: CGPoint(x: size.width * 0.46, y: size.height * 0.2)
                )
                context.stroke(arc, with: .color(PUColor.lime),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 3]))

                let ball = CGRect(x: size.width * 0.82 - 5, y: size.height * 0.56 - 5, width: 10, height: 10)
                context.fill(Circle().path(in: ball), with: .color(PUColor.lime))
            }
            .padding(8)
        }
        .frame(width: 74, height: 62)
        .accessibilityHidden(true)
    }
}
