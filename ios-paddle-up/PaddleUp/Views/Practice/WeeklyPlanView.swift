//
//  WeeklyPlanView.swift
//  PaddleUp
//

import SwiftUI

struct WeeklyPlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let plan = appState.weeklyPlan {
                    rationaleCard(plan)
                    ForEach(plan.entries.sorted { $0.weekday < $1.weekday }) { entry in
                        entryRow(entry)
                    }
                } else {
                    PUCard { PUEmptyState(symbol: "calendar", title: "No plan yet",
                                          message: "Complete a session or your baseline assessment to generate a personalised week.") }
                }
                regenerateButton
            }
            .padding(PUMetrics.margin)
        }
        .puScreenBackground()
        .navigationTitle("Weekly Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func rationaleCard(_ plan: WeeklyPlan) -> some View {
        PUCard(background: PUColor.limeDim) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Why this plan").puMicroLabel()
                Text(plan.rationale)
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func entryRow(_ entry: WeeklyPlan.Entry) -> some View {
        let drill = DrillLibrary.drill(id: entry.drillID)
        return Button {
            guard let drill else { return }
            router.startPractice(PracticeConfiguration(
                shot: entry.shot, mode: entry.isAssessment ? .assessment : .drill,
                drillID: entry.isAssessment ? nil : drill.id,
                length: appState.settings.defaultSessionLength
            ))
        } label: {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(entry.weekdayName.prefix(3).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PUColor.textTertiary)
                    Image(systemName: entry.completedAt != nil ? "checkmark.circle.fill" : entry.isAssessment ? "flag.checkered" : entry.shot.group.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(entry.completedAt != nil ? PUColor.lime : PUColor.textSecondary)
                }
                .frame(width: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.isAssessment ? "Assessment Session" : drill?.name ?? entry.shot.displayName)
                        .font(PUFont.headline)
                        .foregroundStyle(PUColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(entry.isAssessment ? "Measure progress on \(entry.mechanic.displayName.lowercased())"
                                            : "\(entry.shot.group.displayName) · \(entry.mechanic.displayName)")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
                Spacer(minLength: 0)
                if entry.completedAt == nil {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(PUColor.lime)
                }
            }
            .padding(14)
            .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.tileRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                    .strokeBorder(PUColor.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var regenerateButton: some View {
        Button {
            appState.regeneratePlan()
            Haptics.success()
        } label: {
            Label("Regenerate plan", systemImage: "arrow.clockwise")
        }
        .buttonStyle(PUSecondaryButtonStyle())
    }
}
