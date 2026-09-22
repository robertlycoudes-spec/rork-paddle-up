//
//  MechanicDetailView.swift
//  PaddleUp
//
//  One mechanic over time, with its benchmark, common mistakes and drill.
//

import SwiftUI

struct MechanicDetailView: View {
    let mechanic: MechanicID
    let group: ShotGroup

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router

    private var history: [MechanicHistoryPoint] { appState.history(for: mechanic, group: group) }
    private var shot: ShotType { appState.reps(for: group).last?.shot ?? .forehandDink }
    private var drill: Drill? { DrillLibrary.drill(for: mechanic, shot: shot) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                if history.count >= 2 { trendCard }
                benchmarkCard
                if let issue = relatedIssue { explanationCard(issue) }
                if let drill { drillCard(drill) }
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .puScreenBackground()
        .navigationTitle(mechanic.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var headerCard: some View {
        PUCard(padding: 18) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.displayName) · current").puMicroLabel()
                    Text(history.last.map { "\(Int($0.score))" } ?? "—")
                        .font(PUFont.hero)
                        .foregroundStyle(PUColor.textPrimary)
                    if let delta = appState.improvement(for: mechanic, group: group) {
                        Text("\(delta >= 0 ? "+" : "")\(Int(delta)) this month")
                            .font(PUFont.caption)
                            .foregroundStyle(delta >= 0 ? PUColor.lime : PUColor.alert)
                    }
                }
                Spacer()
                PUIconBadge(symbol: "figure.pickleball", size: 56)
            }
        }
    }

    private var trendCard: some View {
        PUCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Every session").puMicroLabel()
                MechanicSparkline(points: history.suffix(12).map(\.score))
                    .frame(height: 110)
                HStack {
                    Text(history.first.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "")
                        .font(.system(size: 11)).foregroundStyle(PUColor.textTertiary)
                    Spacer()
                    Text("\(history.count) sessions")
                        .font(.system(size: 11)).foregroundStyle(PUColor.textTertiary)
                    Spacer()
                    Text(history.last.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "")
                        .font(.system(size: 11)).foregroundStyle(PUColor.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var benchmarkCard: some View {
        if let range = BenchmarkLibrary.range(shot: shot, mechanic: mechanic) {
            PUCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Benchmark").puMicroLabel()
                    HStack {
                        Text("Target range")
                            .font(PUFont.body).foregroundStyle(PUColor.textSecondary)
                        Spacer()
                        Text("\(format(range.idealLow, range.unit)) – \(format(range.idealHigh, range.unit))")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PUColor.lime)
                    }
                    Divider().overlay(PUColor.hairline)
                    Text(sourceNote(range.source))
                        .font(.system(size: 12))
                        .foregroundStyle(PUColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func explanationCard(_ issue: CoachingIssue) -> some View {
        PUCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Common mistake").puMicroLabel()
                Text(issue.title)
                    .font(PUFont.headline)
                    .foregroundStyle(PUColor.textPrimary)
                Text(issue.explanation)
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(PUColor.hairline)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(PUColor.lime)
                    Text(issue.correction)
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func drillCard(_ drill: Drill) -> some View {
        NavigationLink { DrillDetailView(drill: drill) } label: {
            PUCard(background: PUColor.limeDim) {
                HStack(spacing: 14) {
                    DrillThumbnail(mechanic: drill.targetMechanic)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Drill for this mechanic").puMicroLabel()
                        Text(drill.name)
                            .font(PUFont.headline)
                            .foregroundStyle(PUColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text(drill.prescription)
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PUColor.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var relatedIssue: CoachingIssue? {
        CoachingKnowledgeBase.issues.first { $0.mechanic == mechanic && $0.applies(to: shot) }
    }

    private func format(_ value: Double, _ unit: String) -> String {
        unit == "°" ? "\(Int(value.rounded()))°" : String(format: "%.2f %@", value, unit)
    }

    private func sourceNote(_ source: BenchmarkSource) -> String {
        switch source {
        case .coachingHeuristic:
            return "This range comes from coaching heuristics, not validated sports-science thresholds. Paddle Up will tighten it as coach review and real usage data accumulate."
        case .eliteFootage:
            return "Derived from reviewed elite footage."
        case .aggregateUsage:
            return "Learned from aggregate Paddle Up usage data."
        }
    }
}
