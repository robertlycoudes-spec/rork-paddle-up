//
//  SessionSummaryView.swift
//  PaddleUp
//
//  Post-session review: headline stats, mechanics breakdown, the single
//  biggest focus, and the drill prescribed to fix it.
//

import SwiftUI

struct SessionSummaryView: View {
    let session: SessionRecord
    var isModal: Bool = false

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var focus: RepCoaching? { CoachingEngine.sessionFocus(for: session) }
    private var recommendedDrill: Drill? {
        focus?.drillID.flatMap(DrillLibrary.drill(id:))
            ?? session.weakestMechanic.flatMap { DrillLibrary.drill(for: $0.mechanic, shot: session.shot) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                sessionHeader
                statStrip
                mechanicsBreakdown
                calloutRow
                if let focus { focusCard(focus) }
                repList
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .puScreenBackground()
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let drill = recommendedDrill {
                Button {
                    startDrill(drill)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("START DRILL")
                    }
                }
                .buttonStyle(PUPrimaryButtonStyle())
                .padding(.horizontal, PUMetrics.margin)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Sections

    private var sessionHeader: some View {
        PUCard {
            HStack(spacing: 14) {
                PUIconBadge(symbol: session.shot.group.symbol, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(session.shot.group.displayName) \(session.mode.displayName)")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(PUColor.textPrimary)
                    Text("Duration \(durationString) · \(session.activeReps.count) reps")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var statStrip: some View {
        PUStatStrip(items: [
            .init(label: "Average\nScore", value: session.averageScore.map { "\(Int($0))" } ?? "—"),
            .init(label: "Best\nRep", value: session.bestScore.map { "\(Int($0))" } ?? "—"),
            .init(label: "Worst\nRep", value: session.worstScore.map { "\(Int($0))" } ?? "—"),
            .init(label: "Consist\nency", value: session.consistency.map { "\(Int($0))%" } ?? "—")
        ])
    }

    private var mechanicsBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Mechanics breakdown")
            PUCard(padding: 14) {
                VStack(spacing: 2) {
                    ForEach(session.orderedMechanicAverages, id: \.mechanic) { entry in
                        NavigationLink(value: SummaryRoute.mechanic(entry.mechanic, session.shot.group)) {
                            PUMechanicRow(title: entry.mechanic.displayName, value: entry.score)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationDestination(for: SummaryRoute.self) { route in
            switch route {
            case .mechanic(let mechanic, let group):
                MechanicDetailView(mechanic: mechanic, group: group)
            case .rep(let repID):
                if let rep = session.reps.first(where: { $0.id == repID }) {
                    RepDetailView(rep: rep)
                }
            }
        }
    }

    private var calloutRow: some View {
        HStack(spacing: PUMetrics.gutter) {
            CalloutTile(
                symbol: "scope",
                tint: PUColor.alert,
                label: "Biggest weakness",
                value: session.weakestMechanic?.mechanic.displayName ?? "—"
            )
            CalloutTile(
                symbol: "chart.bar.fill",
                tint: PUColor.lime,
                label: "Biggest improvement",
                value: improvementText
            )
        }
    }

    private var improvementText: String {
        guard let best = bestImprovement else { return "Building baseline" }
        return "\(best.mechanic.displayName) +\(Int(best.delta))"
    }

    /// Compares this session's mechanic averages against the previous session
    /// for the same shot group.
    private var bestImprovement: (mechanic: MechanicID, delta: Double)? {
        let previous = appState.completedSessions
            .filter { $0.id != session.id && $0.shot.group == session.shot.group
                && $0.startedAt < session.startedAt }
            .max { $0.startedAt < $1.startedAt }
        guard let previous else { return nil }
        let previousAverages = previous.mechanicAverages

        var best: (MechanicID, Double)?
        for (mechanic, score) in session.mechanicAverages {
            guard let before = previousAverages[mechanic] else { continue }
            let delta = score - before
            if delta > 0.5, best == nil || delta > best!.1 { best = (mechanic, delta) }
        }
        return best.map { (mechanic: $0.0, delta: $0.1) }
    }

    private func focusCard(_ focus: RepCoaching) -> some View {
        PUCard(background: PUColor.limeDim) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    PUIconBadge(symbol: "lightbulb.fill", size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your #1 focus").puMicroLabel()
                        Text(focus.correction)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(PUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let issue = focus.issue {
                    Text(issue.explanation)
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let drill = recommendedDrill {
                    Divider().overlay(PUColor.hairline)
                    HStack(spacing: 14) {
                        DrillThumbnail(mechanic: drill.targetMechanic)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Recommended next drill").puMicroLabel()
                            Text(drill.name)
                                .font(PUFont.headline)
                                .foregroundStyle(PUColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text(drill.prescription)
                                .font(PUFont.caption)
                                .foregroundStyle(PUColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var repList: some View {
        let reps = session.activeReps
        if !reps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                PUSectionHeader(title: "Reps", accessory: "\(reps.count)")
                PUCard(padding: 6) {
                    VStack(spacing: 0) {
                        ForEach(Array(reps.suffix(12).reversed())) { rep in
                            NavigationLink(value: SummaryRoute.rep(rep.id)) {
                                RepSummaryRow(rep: rep)
                            }
                            .buttonStyle(.plain)
                            if rep.id != reps.suffix(12).reversed().last?.id {
                                Divider().overlay(PUColor.hairline).padding(.leading, 52)
                            }
                        }
                    }
                }
                if reps.count > 12 {
                    Text("Showing the 12 most recent reps.")
                        .font(.system(size: 12))
                        .foregroundStyle(PUColor.textTertiary)
                }
            }
        }
    }

    private var durationString: String {
        let total = Int(session.duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func startDrill(_ drill: Drill) {
        guard store.canStartSession(completedSessions: appState.completedSessionCount) else {
            dismiss()
            router.showsPaywall = true
            return
        }
        appState.analytics.record(.drillStarted, properties: ["drill": drill.id])
        dismiss()
        router.startPractice(PracticeConfiguration(
            shot: drill.shot, mode: .drill, drillID: drill.id,
            length: appState.settings.defaultSessionLength
        ))
    }
}

nonisolated enum SummaryRoute: Hashable {
    case mechanic(MechanicID, ShotGroup)
    case rep(UUID)
}

struct CalloutTile: View {
    let symbol: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 11) {
            PUIconBadge(symbol: symbol, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).puMicroLabel()
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PUColor.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                .strokeBorder(PUColor.hairline, lineWidth: 1)
        )
    }
}

struct RepSummaryRow: View {
    let rep: RepRecord

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rep.index)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(PUColor.textTertiary)
                .frame(width: 30, alignment: .leading)
            Text("\(Int(rep.score))")
                .font(.system(size: 19, weight: .bold).monospacedDigit())
                .foregroundStyle(PUColor.score(rep.score))
                .frame(width: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(rep.dominantIssue?.displayName ?? "Clean rep")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PUColor.textPrimary)
                if rep.clipFilename != nil {
                    Label("Clip saved", systemImage: "play.rectangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(PUColor.textTertiary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PUColor.textTertiary)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 10)
        .contentShape(.rect)
    }
}
