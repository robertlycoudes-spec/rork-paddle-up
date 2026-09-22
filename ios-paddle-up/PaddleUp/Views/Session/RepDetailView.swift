//
//  RepDetailView.swift
//  PaddleUp
//
//  A single rep: clip replay with pose overlay, mechanic breakdown, the one
//  correction, and the controls to delete or reclassify it.
//

import AVKit
import SwiftUI

struct RepDetailView: View {
    let rep: RepRecord

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showingReclassify = false
    @State private var showingDeleteConfirmation = false
    @State private var player: AVPlayer?
    @State private var overlayFrameIndex: Int = 0
    @State private var isPlayingOverlay = false

    private var issue: CoachingIssue? { rep.issueID.flatMap(CoachingKnowledgeBase.issue(id:)) }
    private var drill: Drill? { rep.recommendedDrillID.flatMap(DrillLibrary.drill(id:)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                replayCard
                scoreCard
                if let issue { issueCard(issue) }
                mechanicsCard
                if let drill { drillCard(drill) }
                correctionControls
            }
            .padding(.horizontal, PUMetrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .puScreenBackground()
        .navigationTitle("Rep \(rep.index)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: loadClip)
        .confirmationDialog("Delete this rep?", isPresented: $showingDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete rep", role: .destructive) {
                appState.deleteRep(rep)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the rep from your scores and deletes its clip. Paddle Up uses these corrections to improve detection.")
        }
        .sheet(isPresented: $showingReclassify) {
            ReclassifySheet(rep: rep) { newShot in
                appState.reclassifyRep(rep, to: newShot)
                dismiss()
            }
        }
    }

    // MARK: - Replay

    private var replayCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PUMetrics.cardRadius)
                .fill(PUColor.canvasDeep)

            if let player {
                VideoPlayer(player: player)
                    .clipShape(.rect(cornerRadius: PUMetrics.cardRadius))
                    .allowsHitTesting(true)
            } else if !rep.poseFrames.isEmpty {
                // No clip saved — replay the stored pose sequence instead.
                PoseSkeletonOverlay(frame: rep.poseFrames[safe: overlayFrameIndex])
                    .background(PUColor.canvasDeep)
                    .clipShape(.rect(cornerRadius: PUMetrics.cardRadius))
            } else {
                PUEmptyState(symbol: "video.slash",
                             title: "No replay saved",
                             message: "Clip saving was off for this rep.")
            }

            if player == nil && !rep.poseFrames.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Text("Pose replay")
                            .font(PUFont.micro)
                            .foregroundStyle(PUColor.textSecondary)
                        Spacer()
                        Button {
                            isPlayingOverlay.toggle()
                            if isPlayingOverlay { animateOverlay() }
                        } label: {
                            Image(systemName: isPlayingOverlay ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PUColor.limeInk)
                                .frame(width: 32, height: 32)
                                .background(PUColor.lime, in: .circle)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(height: 300)
    }

    private func loadClip() {
        guard let filename = rep.clipFilename, let url = appState.clipURL(for: filename),
              FileManager.default.fileExists(atPath: url.path) else { return }
        let item = AVPlayerItem(url: url)
        let created = AVPlayer(playerItem: item)
        created.isMuted = true
        player = created
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: item, queue: .main) { _ in
            created.seek(to: .zero)
            created.play()
        }
        created.play()
    }

    private func animateOverlay() {
        guard isPlayingOverlay, !rep.poseFrames.isEmpty else { return }
        Task {
            while isPlayingOverlay {
                try? await Task.sleep(for: .milliseconds(70))
                await MainActor.run {
                    overlayFrameIndex = (overlayFrameIndex + 1) % max(1, rep.poseFrames.count)
                }
            }
        }
    }

    // MARK: - Cards

    private var scoreCard: some View {
        PUCard(padding: 18) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paddle Up Score").puMicroLabel()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(rep.score))")
                            .font(PUFont.hero)
                            .foregroundStyle(PUColor.textPrimary)
                        Text("/ 100")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PUColor.textSecondary)
                    }
                    Text(rep.shot.displayName)
                        .font(PUFont.caption)
                        .foregroundStyle(PUColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    ConfidenceBadge(confidence: rep.confidence)
                    if rep.wasReclassified {
                        Text("Reclassified")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PUColor.amber)
                    }
                }
            }
        }
    }

    private func issueCard(_ issue: CoachingIssue) -> some View {
        PUCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    PUIconBadge(symbol: "scope", tint: PUColor.alert)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Main issue").puMicroLabel()
                        Text(issue.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(PUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(issue.explanation)
                    .font(PUFont.body)
                    .foregroundStyle(PUColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(PUColor.hairline)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(PUColor.lime)
                        .frame(width: 24)
                    Text(issue.correction)
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var mechanicsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PUSectionHeader(title: "Mechanics")
            PUCard(padding: 14) {
                VStack(spacing: 4) {
                    ForEach(rep.mechanics) { mechanic in
                        VStack(spacing: 2) {
                            PUMechanicRow(title: mechanic.mechanic.displayName,
                                          value: mechanic.score, showsChevron: false)
                            HStack {
                                Text("Measured \(formatted(mechanic))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(PUColor.textTertiary)
                                Spacer()
                                if let range = BenchmarkLibrary.range(shot: rep.shot,
                                                                      mechanic: mechanic.mechanic) {
                                    Text("Target \(format(range.idealLow, unit: range.unit))–\(format(range.idealHigh, unit: range.unit))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PUColor.textTertiary)
                                }
                            }
                        }
                    }
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
                        Text("Prescribed drill").puMicroLabel()
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

    private var correctionControls: some View {
        VStack(spacing: 10) {
            Button {
                showingReclassify = true
            } label: {
                Label("Wrong shot type", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(PUSecondaryButtonStyle())

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Not a real rep — delete", systemImage: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PUColor.alert)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(PUColor.alertDim, in: .capsule)
            }
            .buttonStyle(.plain)

            Text("Corrections are stored so Paddle Up's detection improves over time.")
                .font(.system(size: 11))
                .foregroundStyle(PUColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private func formatted(_ mechanic: MechanicScore) -> String {
        format(mechanic.rawValue, unit: mechanic.unit)
    }

    private func format(_ value: Double, unit: String) -> String {
        unit == "°" ? "\(Int(value.rounded()))°" : String(format: "%.2f", value)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    private var label: String {
        switch confidence {
        case ..<0.45: return "Low confidence"
        case ..<0.7: return "Medium confidence"
        default: return "High confidence"
        }
    }

    private var tint: Color {
        switch confidence {
        case ..<0.45: return PUColor.alert
        case ..<0.7: return PUColor.amber
        default: return PUColor.lime
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: .capsule)
    }
}

struct ReclassifySheet: View {
    let rep: RepRecord
    let onSelect: (ShotType) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What shot was this really?")
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textSecondary)
                        .padding(.bottom, 4)
                    ForEach(ShotType.allCases) { shot in
                        Button {
                            onSelect(shot)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: shot.group.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PUColor.lime)
                                    .frame(width: 24)
                                Text(shot.displayName)
                                    .font(PUFont.body)
                                    .foregroundStyle(PUColor.textPrimary)
                                Spacer()
                                if shot == rep.shot {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(PUColor.lime)
                                }
                            }
                            .padding(14)
                            .background(PUColor.surface, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PUMetrics.margin)
            }
            .puScreenBackground()
            .navigationTitle("Correct shot type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }
}
