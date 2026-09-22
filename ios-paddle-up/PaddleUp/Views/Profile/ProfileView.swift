//
//  ProfileView.swift
//  PaddleUp
//
//  The Paddle Up skill card: overall rating, per-shot scores, strongest and
//  weakest shots, trend, and recent activity.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @Environment(PracticeRouter.self) private var router

    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    identityCard
                    if appState.shotRatings.isEmpty {
                        emptyRatings
                    } else {
                        shotRatingsCard
                        strongWeakRow
                        trendCard
                    }
                    swingMatchTeaser
                    activityCard
                }
                .padding(.horizontal, PUMetrics.margin)
                .padding(.bottom, 24)
            }
            .puScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShotGroup.self) { group in
                ShotDetailView(group: group)
            }
            .navigationDestination(for: SummaryRoute.self) { route in
                switch route {
                case .mechanic(let mechanic, let group):
                    MechanicDetailView(mechanic: mechanic, group: group)
                case .rep:
                    EmptyView()
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }

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

    private var identityCard: some View {
        HStack(spacing: 16) {
            Text(appState.profile.initials)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(PUColor.lime.opacity(0.85))
                .frame(width: 92, height: 92)
                .background(PUColor.lime.opacity(0.13), in: .circle)
                .overlay(Circle().strokeBorder(PUColor.lime.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.profile.displayName.isEmpty ? "Player" : appState.profile.displayName)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(PUColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Overall Paddle Up Rating").puMicroLabel()
                Text(appState.overallRating.map { "\(Int($0))" } ?? "—")
                    .font(.system(size: 44, weight: .heavy).monospacedDigit())
                    .foregroundStyle(PUColor.textPrimary)
                if store.isPro {
                    Text("PADDLE UP PRO")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(PUColor.limeInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PUColor.lime, in: .capsule)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var emptyRatings: some View {
        PUCard {
            PUEmptyState(
                symbol: "figure.pickleball",
                title: "No rating yet",
                message: "Complete your first session and Paddle Up will build your skill card."
            )
        }
    }

    private var shotRatingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Shot ratings")
            PUCard(padding: 14) {
                VStack(spacing: 2) {
                    ForEach(appState.shotRatings) { rating in
                        NavigationLink(value: rating.group) {
                            HStack(spacing: 12) {
                                Image(systemName: rating.group.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PUColor.lime)
                                    .frame(width: 26, height: 26)
                                    .background(PUColor.lime.opacity(0.12), in: .circle)
                                Text(rating.group.displayName)
                                    .font(PUFont.body)
                                    .foregroundStyle(PUColor.textPrimary)
                                    .frame(width: 104, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                PUScoreBar(value: rating.score)
                                Text("\(Int(rating.score))")
                                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(PUColor.textPrimary)
                                    .frame(width: 28, alignment: .trailing)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(PUColor.textTertiary)
                            }
                            .padding(.vertical, 7)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("Paddle Up Rating is Paddle Up's own mechanics score. It is not a DUPR rating.")
                .font(.system(size: 11))
                .foregroundStyle(PUColor.textTertiary)
        }
    }

    private var strongWeakRow: some View {
        HStack(spacing: PUMetrics.gutter) {
            CalloutTile(symbol: "trophy.fill", tint: PUColor.lime, label: "Strongest shot",
                        value: appState.strongestShot?.group.displayName ?? "—")
            CalloutTile(symbol: "arrow.down.circle.fill", tint: PUColor.alert, label: "Weakest shot",
                        value: appState.weakestShot?.group.displayName ?? "—")
        }
    }

    @ViewBuilder
    private var trendCard: some View {
        if let group = appState.strongestShot?.group {
            let trend = appState.weeklyTrend(for: group)
            if trend.count >= 2 {
                PUCard {
                    VStack(alignment: .leading, spacing: 12) {
                        PUSectionHeader(title: "Rating trend", accessory: group.displayName)
                        TrendChart(points: trend).frame(height: 150)
                    }
                }
            }
        }
    }

    private var swingMatchTeaser: some View {
        NavigationLink {
            SwingMatchView(group: appState.strongestShot?.group ?? .dink)
        } label: {
            PUCard {
                HStack(spacing: 14) {
                    PUIconBadge(symbol: "person.2.fill", size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Swing Match")
                                .font(PUFont.headline)
                                .foregroundStyle(PUColor.textPrimary)
                            if store.isLocked(.swingMatch) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PUColor.amber)
                            }
                        }
                        Text("Compare your mechanics to elite references")
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

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Recent activity")
            PUCard(padding: 14) {
                VStack(spacing: 14) {
                    ActivityRow(
                        symbol: "figure.strengthtraining.traditional",
                        title: "\(appState.completedSessionCount) sessions completed",
                        detail: "\(appState.totalRepCount) reps measured"
                    )
                    if let improvement = appState.biggestImprovement {
                        Divider().overlay(PUColor.hairline)
                        ActivityRow(
                            symbol: "chart.bar.fill",
                            title: improvement.mechanic.displayName,
                            detail: "+\(Int(improvement.delta)) this month",
                            detailIsPositive: true
                        )
                    }
                    if appState.practiceStreak > 0 {
                        Divider().overlay(PUColor.hairline)
                        ActivityRow(
                            symbol: "flame.fill",
                            title: "\(appState.practiceStreak)-day practice streak",
                            detail: "Keep it going"
                        )
                    }
                }
            }
        }
    }
}

struct ActivityRow: View {
    let symbol: String
    let title: String
    let detail: String
    var detailIsPositive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            PUIconBadge(symbol: symbol, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textPrimary)
                Text(detail)
                    .font(PUFont.caption)
                    .foregroundStyle(detailIsPositive ? PUColor.lime : PUColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}
