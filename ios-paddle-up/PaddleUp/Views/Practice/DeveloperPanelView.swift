//
//  DeveloperPanelView.swift
//  PaddleUp
//
//  Hidden tuning surface. Critical for calibrating the detector and rubrics
//  against real players before those numbers are trusted.
//

import SwiftUI
import UniformTypeIdentifiers

struct DeveloperPanelView: View {
    let engine: PracticeEngine

    @Environment(\.dismiss) private var dismiss
    @State private var exportedJSON: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detectorSection
                    if let pose = engine.currentPose { jointSection(pose: pose) }
                    if let feedback = engine.latestFeedback { analysisSection(feedback: feedback) }
                    exportSection
                }
                .padding(PUMetrics.margin)
            }
            .puScreenBackground()
            .navigationTitle("Developer Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private var detectorSection: some View {
        PUCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rep detection").puMicroLabel()
                DebugRow(label: "State", value: engine.detectorState.rawValue)
                DebugRow(label: "Wrist speed", value: String(format: "%.2f ×shoulder/s", engine.liveWristSpeed))
                DebugRow(label: "Reps accepted", value: "\(engine.repCount)")
                DebugRow(label: "Last rejection", value: engine.lastRejection?.rawValue ?? "none")
                DebugRow(label: "Classifier confidence",
                         value: String(format: "%.2f", engine.lastClassificationConfidence))
            }
        }
    }

    private func jointSection(pose: PoseFrame) -> some View {
        PUCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pose").puMicroLabel()
                DebugRow(label: "Mean confidence", value: String(format: "%.2f", pose.meanConfidence))
                DebugRow(label: "Shoulder width", value: String(format: "%.3f", pose.shoulderWidth))
                DebugRow(label: "Torso length", value: String(format: "%.3f", pose.torsoLength))
                DebugRow(label: "Body scale", value: String(format: "%.3f", pose.bodyScale))
                DebugRow(label: "Joints tracked", value: "\(pose.joints.count)")
                if let leftKnee = kneeAngle(pose, side: .left) {
                    DebugRow(label: "Left knee angle", value: String(format: "%.0f°", leftKnee))
                }
                if let rightKnee = kneeAngle(pose, side: .right) {
                    DebugRow(label: "Right knee angle", value: String(format: "%.0f°", rightKnee))
                }
            }
        }
    }

    private func analysisSection(feedback: LiveRepFeedback) -> some View {
        PUCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Last rep").puMicroLabel()
                DebugRow(label: "Shot", value: feedback.rep.shot.rawValue)
                DebugRow(label: "Score", value: String(Int(feedback.rep.score)))
                DebugRow(label: "Confidence", value: String(format: "%.2f", feedback.rep.confidence))
                DebugRow(label: "Dominant issue", value: feedback.rep.dominantIssue?.rawValue ?? "none")
                Divider().overlay(PUColor.hairline)
                ForEach(feedback.rep.mechanics) { mechanic in
                    DebugRow(
                        label: mechanic.mechanic.displayName,
                        value: "\(Int(mechanic.score))  (\(String(format: "%.2f", mechanic.rawValue)) \(mechanic.unit))"
                    )
                }
            }
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                exportedJSON = buildJSON()
                if let exportedJSON { UIPasteboard.general.string = exportedJSON }
                Haptics.success()
            } label: {
                Label("Copy analysis JSON", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(PUSecondaryButtonStyle())

            if let exportedJSON {
                Text(exportedJSON)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(PUColor.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PUColor.surface, in: .rect(cornerRadius: 12))
                    .textSelection(.enabled)
            }
        }
    }

    private func kneeAngle(_ pose: PoseFrame, side: Handedness) -> Double? {
        let joints: (PoseJoint, PoseJoint, PoseJoint) = side == .left
            ? (.leftHip, .leftKnee, .leftAnkle)
            : (.rightHip, .rightKnee, .rightAnkle)
        guard let hip = pose.point(joints.0), let knee = pose.point(joints.1),
              let ankle = pose.point(joints.2) else { return nil }
        return PoseGeometry.angle(hip, knee, ankle)
    }

    private func buildJSON() -> String {
        guard let rep = engine.latestFeedback?.rep else { return "{}" }
        let payload = CoachingEngine.structuredPayload(for: rep, trend: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

struct DebugRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(PUColor.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(PUColor.textPrimary)
        }
    }
}
