//
//  ShotDetailView.swift
//  PaddleUp
//
//  Deep dive on one shot group: rubric, mechanic breakdown, trend, drills.
//

import SwiftUI

struct ShotDetailView: View {
    let group: ShotGroup

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router

    private var reps: [RepRecord] { appState.reps(for: group) }
    private var shot: ShotType { reps.last?.shot ?? defaultShot }
    private var rating: ShotRating? { appState.shotRatings.first { $0.group == group } }

    private var defaultShot: ShotType {
        ShotType.allCases.first { $0.group == group } ?? .forehandDink
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if rating != nil {
                    trendCard
                    mechanicsCard
                } else {
                    PUCard { PUEmptyState(symbol: group.symbol.isEmpty ? "circle" : group.symbol,
                                          title: "No reps yet",
                                          message: "Practice this shot to start building its rating.") }
                }
                drillsSection
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .puScreenBackground()
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            Button {
                start()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("PRACTICE \(group.displayName.uppercased())")
                }
            }
            .buttonStyle(PUPrimaryButtonStyle())
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var header: some View {
        PUCard(padding: 18) {
            HStack(spacing: 18) {
                PUIconBadge(symbol: group.symbol, size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rating.map { "\(Int($0.score))" } ?? "—")
                        .font(PUFont.hero)
                        .foregroundStyle(PUColor.textPrimary)
                    if let delta = rating?.delta {
                        Text("\(delta >= 0 ? "+" : "")\(Int(delta)) recently")
                            .font(PUFont.caption)
                            .foregroundStyle(delta >= 0 ? PUColor.lime : PUColor.alert)
                    }
                    Text("\(rating?.repCount ?? 0) reps measured")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var trendCard: some View {
        let trend = appState.weeklyTrend(for: group)
        return Group {
            if trend.count >= 2 {
                PUCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Score trend").puMicroLabel()
                        TrendChart(points: trend).frame(height: 140)
                    }
                }
            }
        }
    }

    private var mechanicsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Mechanics rubric",
                            accessory: "v\(RubricLibrary.rubric(for: shot).version)")
            PUCard(padding: 14) {
                VStack(spacing: 2) {
                    ForEach(RubricLibrary.rubric(for: shot).components) { component in
                        let history = appState.history(for: component.mechanic, group: group)
                        HStack(spacing: 10) {
                            NavigationLink(value: SummaryRoute.mechanic(component.mechanic, group)) {
                                HStack(spacing: 10) {
                                    Text(component.mechanic.displayName)
                                        .font(PUFont.body)
                                        .foregroundStyle(PUColor.textPrimary)
                                        .frame(width: 130, alignment: .leading)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    if let latest = history.last {
                                        PUScoreBar(value: latest.score)
                                        Text("\(Int(latest.score))")
                                            .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                            .foregroundStyle(PUColor.textPrimary)
                                            .frame(width: 28, alignment: .trailing)
                                    } else {
                                        Text("\(Int(component.weight * 100))% weight")
                                            .font(PUFont.caption)
                                            .foregroundStyle(PUColor.textTertiary)
                                        Spacer()
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(PUColor.textTertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Drills for this shot")
            ForEach(DrillLibrary.drills(for: shot)) { drill in
                NavigationLink { DrillDetailView(drill: drill) } label: {
                    DrillRow(drill: drill)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func start() {
        router.startPractice(PracticeConfiguration(
            shot: shot, mode: .freePractice, drillID: nil,
            length: appState.settings.defaultSessionLength
        ))
    }
}
