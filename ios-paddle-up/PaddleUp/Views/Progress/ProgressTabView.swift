//
//  ProgressTabView.swift
//  PaddleUp
//
//  History and trends: are you actually improving?
//

import SwiftUI

struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @Environment(PracticeRouter.self) private var router

    @State private var selectedGroup: ShotGroup = .dink

    private var ratedGroups: [ShotGroup] {
        let rated = appState.shotRatings.map(\.group)
        return rated.isEmpty ? [.dink] : rated
    }

    private var visibleSessions: [SessionRecord] {
        let all = appState.completedSessions
        guard let limit = store.sessionHistoryLimit() else { return all }
        return Array(all.prefix(limit))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.completedSessions.isEmpty {
                        emptyState
                    } else {
                        groupPicker
                        trendCard
                        mechanicProgress
                        insightsSection
                        historySection
                    }
                }
                .padding(.horizontal, PUMetrics.margin)
                .padding(.bottom, 24)
            }
            .puScreenBackground()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(PUColor.canvas, for: .navigationBar)
            .navigationDestination(for: SummaryRoute.self) { route in
                switch route {
                case .mechanic(let mechanic, let group):
                    MechanicDetailView(mechanic: mechanic, group: group)
                case .rep:
                    EmptyView()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let session = appState.session(id: id) {
                    SessionSummaryView(session: session)
                }
            }
            .onAppear {
                if !ratedGroups.contains(selectedGroup) { selectedGroup = ratedGroups[0] }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            PUEmptyState(
                symbol: "chart.line.uptrend.xyaxis",
                title: "No progress yet",
                message: "Finish a practice session and Paddle Up will start tracking every mechanic over time."
            )
        }
        .padding(.top, 40)
    }

    private var groupPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ratedGroups) { group in
                    Button {
                        Haptics.tap()
                        selectedGroup = group
                    } label: {
                        Text(group.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedGroup == group ? PUColor.limeInk : PUColor.textSecondary)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(selectedGroup == group ? PUColor.lime : PUColor.surface, in: .capsule)
                            .overlay(Capsule().strokeBorder(
                                selectedGroup == group ? .clear : PUColor.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollClipDisabled()
    }

    private var trendCard: some View {
        let trend = appState.weeklyTrend(for: selectedGroup)
        return PUCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(selectedGroup.displayName) score trend").puMicroLabel()
                    Spacer()
                    if let rating = appState.shotRatings.first(where: { $0.group == selectedGroup }) {
                        Text("\(Int(rating.score))")
                            .font(.system(size: 20, weight: .bold).monospacedDigit())
                            .foregroundStyle(PUColor.score(rating.score))
                    }
                }
                if trend.count >= 2 {
                    TrendChart(points: trend)
                        .frame(height: 150)
                } else {
                    Text("Complete sessions across more than one week to see a trend.")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    private var mechanicProgress: some View {
        let mechanics = RubricLibrary.rubric(for: primaryShot).components.map(\.mechanic)
        return VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Mechanic history")
            PUCard(padding: 14) {
                VStack(spacing: 8) {
                    ForEach(mechanics, id: \.self) { mechanic in
                        let history = appState.history(for: mechanic, group: selectedGroup)
                        if let latest = history.last {
                            NavigationLink(value: SummaryRoute.mechanic(mechanic, selectedGroup)) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mechanic.displayName)
                                            .font(PUFont.body)
                                            .foregroundStyle(PUColor.textPrimary)
                                        if let delta = appState.improvement(for: mechanic, group: selectedGroup) {
                                            Text("\(delta >= 0 ? "+" : "")\(Int(delta)) this month")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(delta >= 0 ? PUColor.lime : PUColor.alert)
                                        }
                                    }
                                    .frame(width: 132, alignment: .leading)
                                    MechanicSparkline(points: history.suffix(8).map(\.score))
                                        .frame(height: 34)
                                    Text("\(Int(latest.score))")
                                        .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(PUColor.textPrimary)
                                        .frame(width: 30, alignment: .trailing)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(PUColor.textTertiary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var primaryShot: ShotType {
        appState.reps(for: selectedGroup).last?.shot ?? .forehandDink
    }

    @ViewBuilder
    private var insightsSection: some View {
        let insights = appState.recurringWeaknesses
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                PUSectionHeader(title: "Patterns")
                ForEach(insights.prefix(3)) { insight in
                    PUCard {
                        HStack(alignment: .top, spacing: 12) {
                            PUIconBadge(symbol: insight.trend > 0 ? "arrow.up.right" : "exclamationmark",
                                        tint: insight.trend > 0 ? PUColor.lime : PUColor.amber)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(insight.message)
                                    .font(PUFont.body)
                                    .foregroundStyle(PUColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let drill = insight.drillID.flatMap(DrillLibrary.drill(id:)) {
                                    Button {
                                        router.pendingDrillID = drill.id
                                    } label: {
                                        Text("Open \(drill.name)")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(PUColor.lime)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Session history",
                            accessory: "\(appState.completedSessions.count) total")
            ForEach(visibleSessions) { session in
                NavigationLink(value: session.id) {
                    SessionHistoryRow(session: session)
                }
                .buttonStyle(.plain)
            }
            if store.sessionHistoryLimit() != nil,
               appState.completedSessions.count > visibleSessions.count {
                Button {
                    router.showsPaywall = true
                } label: {
                    PUCard(background: PUColor.limeDim) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill").foregroundStyle(PUColor.lime)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(appState.completedSessions.count - visibleSessions.count) more sessions")
                                    .font(PUFont.headline)
                                    .foregroundStyle(PUColor.textPrimary)
                                Text("Unlock your complete history with Pro")
                                    .font(PUFont.caption)
                                    .foregroundStyle(PUColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SessionHistoryRow: View {
    let session: SessionRecord

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(session.averageScore.map { "\(Int($0))" } ?? "—")
                    .font(.system(size: 19, weight: .bold).monospacedDigit())
                    .foregroundStyle(PUColor.score(session.averageScore ?? 0))
                Text("avg").font(.system(size: 9)).foregroundStyle(PUColor.textTertiary)
            }
            .frame(width: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(session.shot.group.displayName) \(session.mode.displayName)")
                    .font(PUFont.headline)
                    .foregroundStyle(PUColor.textPrimary)
                Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(session.activeReps.count) reps")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
            }
            Spacer(minLength: 4)
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

/// Labelled line chart used for the weekly rating trend.
struct TrendChart: View {
    let points: [(label: String, score: Double)]
    var accent: Color = PUColor.lime

    var body: some View {
        GeometryReader { geo in
            let values = points.map(\.score)
            let minValue = max(0, (values.min() ?? 50) - 12)
            let maxValue = min(100, (values.max() ?? 90) + 12)
            let span = max(1, maxValue - minValue)
            let chartHeight = geo.size.height - 22
            let step = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : geo.size.width

            let pointFor: (Int) -> CGPoint = { index in
                CGPoint(
                    x: CGFloat(index) * step,
                    y: chartHeight * (1 - CGFloat((values[index] - minValue) / span))
                )
            }

            ZStack(alignment: .topLeading) {
                // Gridlines
                ForEach(0..<3, id: \.self) { line in
                    let y = chartHeight * CGFloat(line) / 2
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(PUColor.hairline, lineWidth: 1)
                }

                if values.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: chartHeight))
                        for index in values.indices { path.addLine(to: pointFor(index)) }
                        path.addLine(to: CGPoint(x: geo.size.width, y: chartHeight))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [accent.opacity(0.25), .clear],
                                         startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: pointFor(0))
                        for index in values.indices.dropFirst() { path.addLine(to: pointFor(index)) }
                    }
                    .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(values.indices, id: \.self) { index in
                        let point = pointFor(index)
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                            .position(point)
                        Text("\(Int(values[index]))")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(PUColor.textPrimary)
                            .position(x: point.x, y: max(9, point.y - 15))
                        Text(points[index].label)
                            .font(.system(size: 10))
                            .foregroundStyle(PUColor.textTertiary)
                            .position(x: point.x, y: geo.size.height - 7)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
    }
}
