//
//  SwingMatchView.swift
//  PaddleUp
//
//  Swing Match / Pro Match: similarity to anonymised elite reference profiles,
//  compared on movement, never appearance.
//

import SwiftUI

struct SwingMatchView: View {
    let group: ShotGroup

    @Environment(AppState.self) private var appState
    @Environment(StoreService.self) private var store
    @Environment(PracticeRouter.self) private var router

    @State private var selectedResult: SwingMatchResult?

    private var results: [SwingMatchResult] { appState.swingMatches(for: group) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                if !store.isPro {
                    lockedBanner
                } else if results.isEmpty {
                    PUCard { PUEmptyState(symbol: "person.2.fill", title: "Not enough reps yet",
                                          message: "Log at least 3 reps of this shot to generate a Swing Match.") }
                } else {
                    ForEach(results) { result in
                        Button { selectedResult = result } label: {
                            MatchCard(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                    disclaimer
                }
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .puScreenBackground()
        .navigationTitle("Swing Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedResult) { result in
            NavigationStack { BenchmarkComparisonView(result: result) }
        }
        .onAppear { appState.analytics.record(.swingMatchViewed, properties: ["group": group.rawValue]) }
    }

    private var intro: some View {
        Text("Paddle Up compares your movement — joint angles, timing, contact position — against anonymised elite reference profiles. Never appearance.")
            .font(PUFont.body)
            .foregroundStyle(PUColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var lockedBanner: some View {
        PUCard(background: PUColor.limeDim) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    PUIconBadge(symbol: "lock.fill")
                    Text("Swing Match is a Paddle Up Pro feature")
                        .font(PUFont.headline)
                        .foregroundStyle(PUColor.textPrimary)
                }
                Button("UNLOCK PRO") { router.showsPaywall = true }
                    .buttonStyle(PUPrimaryButtonStyle())
            }
        }
    }

    private var disclaimer: some View {
        Text("References are anonymised movement archetypes (“Elite Reference A”, “Coach Reference”), not licensed professional athletes.")
            .font(.system(size: 11))
            .foregroundStyle(PUColor.textTertiary)
    }
}

struct MatchCard: View {
    let result: SwingMatchResult

    var body: some View {
        PUCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: result.similarity / 100)
                        .stroke(PUColor.score(result.similarity), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(result.similarity))%")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(PUColor.textPrimary)
                }
                .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.profile.displayName)
                        .font(PUFont.headline)
                        .foregroundStyle(PUColor.textPrimary)
                    Text(result.profile.styleDescriptor)
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                    if let closest = result.closestDifference {
                        Text(closest.meaning)
                            .font(.system(size: 12))
                            .foregroundStyle(PUColor.textTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PUColor.textTertiary)
            }
        }
    }
}
