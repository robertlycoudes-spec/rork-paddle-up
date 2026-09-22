//
//  DrillSelectionView.swift
//  PaddleUp
//

import SwiftUI

struct DrillSelectionView: View {
    let shot: ShotType

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router
    @Environment(StoreService.self) private var store

    @State private var selectedDrillID: String?
    @State private var length: SessionLength = .tenMinutes

    private var drills: [Drill] { DrillLibrary.drills(for: shot) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if shot.analyzerStatus == .preview {
                    previewNotice
                }
                freePracticeCard
                drillList
                lengthPicker
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .puScreenBackground()
        .navigationTitle(shot.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            Button {
                startSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text(selectedDrillID == nil ? "START FREE PRACTICE" : "START DRILL")
                }
            }
            .buttonStyle(PUPrimaryButtonStyle())
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            length = appState.settings.defaultSessionLength
        }
    }

    private var previewNotice: some View {
        PUCard(background: PUColor.amber.opacity(0.12)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(PUColor.amber)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview analyzer").puMicroLabel()
                    Text("\(shot.displayName) mechanics are measured for real, but the benchmark ranges are not yet tuned. Treat these scores as directional.")
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var freePracticeCard: some View {
        Button {
            Haptics.tap()
            selectedDrillID = nil
        } label: {
            PUCard(background: selectedDrillID == nil ? PUColor.surfaceRaised : PUColor.surface) {
                HStack(spacing: 14) {
                    PUIconBadge(symbol: "infinity", tint: PUColor.lime)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Free practice")
                            .font(PUFont.headline)
                            .foregroundStyle(PUColor.textPrimary)
                        Text("Just hit. Every rep still gets scored.")
                            .font(PUFont.caption)
                            .foregroundStyle(PUColor.textSecondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: selectedDrillID == nil ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selectedDrillID == nil ? PUColor.lime : PUColor.textTertiary.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var drillList: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Drills", accessory: "\(drills.count)")
            ForEach(drills) { drill in
                Button {
                    Haptics.tap()
                    selectedDrillID = drill.id
                } label: {
                    DrillRow(drill: drill, isSelected: selectedDrillID == drill.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lengthPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Session length")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(SessionLength.allCases) { option in
                    Button {
                        Haptics.tap()
                        length = option
                    } label: {
                        Text(option.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(length == option ? PUColor.limeInk : PUColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(length == option ? PUColor.lime : PUColor.surface, in: .capsule)
                            .overlay(Capsule().strokeBorder(
                                length == option ? .clear : PUColor.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func startSession() {
        guard store.canStartSession(completedSessions: appState.completedSessionCount) else {
            router.showsPaywall = true
            return
        }
        if let selectedDrillID {
            appState.analytics.record(.drillStarted, properties: ["drill": selectedDrillID])
        }
        router.startPractice(PracticeConfiguration(
            shot: shot,
            mode: selectedDrillID == nil ? .freePractice : .drill,
            drillID: selectedDrillID,
            length: length
        ))
    }
}

struct DrillRow: View {
    let drill: Drill
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            DrillThumbnail(mechanic: drill.targetMechanic)
            VStack(alignment: .leading, spacing: 4) {
                Text(drill.name)
                    .font(PUFont.headline)
                    .foregroundStyle(PUColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("Targets \(drill.targetMechanic.displayName)")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.lime)
                Text("\(drill.prescription) · ~\(drill.estimatedMinutes) min")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
            }
            Spacer(minLength: 4)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? PUColor.lime : PUColor.textTertiary.opacity(0.5))
        }
        .padding(14)
        .background(isSelected ? PUColor.surfaceRaised : PUColor.surface,
                    in: .rect(cornerRadius: PUMetrics.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: PUMetrics.tileRadius)
                .strokeBorder(isSelected ? PUColor.lime.opacity(0.5) : PUColor.hairline, lineWidth: 1)
        )
    }
}

struct DrillDetailView: View {
    let drill: Drill

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                goalCard
                instructions
                successCard
                progressCard
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .puScreenBackground()
        .navigationTitle("Drill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            Button {
                startDrill()
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
        .onAppear {
            appState.analytics.record(.recommendationOpened, properties: ["drill": drill.id])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                DrillThumbnail(mechanic: drill.targetMechanic)
                VStack(alignment: .leading, spacing: 4) {
                    Text(drill.shot.displayName).puMicroLabel()
                    Text(drill.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(PUColor.textPrimary)
                        .multilineTextAlignment(.leading)
                }
            }
            HStack(spacing: 8) {
                MetaChip(symbol: "target", text: drill.targetMechanic.displayName)
                MetaChip(symbol: "repeat", text: drill.prescription)
                MetaChip(symbol: "clock", text: "\(drill.estimatedMinutes) min")
            }
        }
    }

    private var goalCard: some View {
        PUCard(background: PUColor.limeDim) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Goal").puMicroLabel()
                Text(drill.goal)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(PUColor.hairline).padding(.vertical, 4)
                Text("Focus cue").puMicroLabel()
                Text("“\(drill.focusCue)”")
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.lime)
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "How to run it")
            PUCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(drill.instructions.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(PUColor.limeInk)
                                .frame(width: 22, height: 22)
                                .background(PUColor.lime, in: .circle)
                            Text(line)
                                .font(PUFont.body)
                                .foregroundStyle(PUColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var successCard: some View {
        PUCard {
            HStack(alignment: .top, spacing: 12) {
                PUIconBadge(symbol: "checkmark.seal.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Success criteria").puMicroLabel()
                    Text(drill.successCriteria)
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var progressCard: some View {
        let history = appState.history(for: drill.targetMechanic, group: drill.shot.group)
        if history.count >= 2 {
            PUCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(drill.targetMechanic.displayName) over time").puMicroLabel()
                    MechanicSparkline(points: history.suffix(8).map(\.score))
                        .frame(height: 64)
                    HStack {
                        Text("\(Int(history.first?.score ?? 0))")
                            .font(PUFont.caption).foregroundStyle(PUColor.textSecondary)
                        Spacer()
                        if let delta = appState.improvement(for: drill.targetMechanic, group: drill.shot.group) {
                            Text("\(delta >= 0 ? "+" : "")\(Int(delta)) since you started")
                                .font(PUFont.caption)
                                .foregroundStyle(delta >= 0 ? PUColor.lime : PUColor.alert)
                        }
                        Spacer()
                        Text("\(Int(history.last?.score ?? 0))")
                            .font(PUFont.caption).foregroundStyle(PUColor.textPrimary)
                    }
                }
            }
        }
    }

    private func startDrill() {
        guard store.canStartSession(completedSessions: appState.completedSessionCount) else {
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

struct MetaChip: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(PUColor.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(PUColor.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(PUColor.hairline, lineWidth: 1))
    }
}

/// Small line chart used for mechanic history.
struct MechanicSparkline: View {
    let points: [Double]
    var accent: Color = PUColor.lime

    var body: some View {
        GeometryReader { geo in
            let values = points
            let minValue = (values.min() ?? 0) - 5
            let maxValue = (values.max() ?? 100) + 5
            let span = max(1, maxValue - minValue)

            ZStack {
                if values.count > 1 {
                    let step = geo.size.width / CGFloat(values.count - 1)
                    let pointFor: (Int) -> CGPoint = { index in
                        CGPoint(
                            x: CGFloat(index) * step,
                            y: geo.size.height * (1 - CGFloat((values[index] - minValue) / span))
                        )
                    }

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for index in values.indices { path.addLine(to: pointFor(index)) }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [accent.opacity(0.28), .clear],
                                         startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: pointFor(0))
                        for index in values.indices.dropFirst() { path.addLine(to: pointFor(index)) }
                    }
                    .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    ForEach(values.indices, id: \.self) { index in
                        Circle()
                            .fill(accent)
                            .frame(width: 6, height: 6)
                            .position(pointFor(index))
                    }
                }
            }
        }
    }
}
