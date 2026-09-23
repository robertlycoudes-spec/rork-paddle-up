//
//  CameraSetupView.swift
//  PaddleUp
//
//  Pre-practice framing check with live guidance. Runs the real camera and
//  pose pipeline so the checks reflect what the analyzer will actually see.
//  The checks coach; only "no player at all" blocks starting.
//

import AVFoundation
import SwiftUI

@MainActor
@Observable
final class CameraSetupModel: NSObject {
    let camera = CameraService()
    private let pose = PoseEngine(frameStride: 3)

    private(set) var currentPose: PoseFrame?
    private(set) var checks: [SetupCheck] = SetupCheckEvaluator.pendingChecks()
    /// A player has been seen recently — the only hard requirement to start.
    private(set) var hasPlayer = false
    /// Every check has held for a few consecutive evaluations.
    private(set) var isIdeal = false
    private var goodFrameStreak = 0
    private var playerStreak = 0
    private var lastPlayerSeen: Date = .distantPast
    private var recentCenters: [CGPoint] = []
    private var lastEvaluation: Date = .distantPast

    private let handedness: Handedness

    /// Checks currently failing while a player is in view.
    var warnings: [SetupCheck] {
        hasPlayer ? checks.filter { $0.status == .warning } : []
    }

    init(handedness: Handedness) {
        self.handedness = handedness
        super.init()
    }

    func start() async {
        pose.delegate = self
        camera.sampleHandler = { [weak self] buffer in
            self?.pose.process(sampleBuffer: buffer, orientation: .right)
        }
        await camera.start()
    }

    func stop() {
        camera.sampleHandler = nil
        camera.stop()
    }

    fileprivate func evaluate(frame: PoseFrame?) {
        currentPose = frame

        // Throttle recomputation so guidance text doesn't flicker.
        guard Date().timeIntervalSince(lastEvaluation) > 0.2 else { return }
        lastEvaluation = .now

        guard let frame, SetupCheckEvaluator.hasPlayer(frame) else {
            playerStreak = 0
            goodFrameStreak = 0
            isIdeal = false
            // Hold the player state briefly so a single dropped frame doesn't
            // snap the start button back to disabled.
            if Date().timeIntervalSince(lastPlayerSeen) > 1.2 {
                hasPlayer = false
                checks = SetupCheckEvaluator.pendingChecks()
            }
            return
        }

        lastPlayerSeen = .now
        playerStreak += 1
        // Two consecutive evaluations (~0.4s) so a flicker can't unlock start.
        if playerStreak >= 2 { hasPlayer = true }

        if let center = frame.hipCenter {
            recentCenters.append(center)
            if recentCenters.count > 12 { recentCenters.removeFirst() }
        }

        let results = SetupCheckEvaluator.evaluate(frame: frame, hand: handedness,
                                                   recentCenters: recentCenters)
        checks = results
        let allPassing = results.allSatisfy { $0.status == .passing }
        goodFrameStreak = allPassing ? goodFrameStreak + 1 : 0
        isIdeal = hasPlayer && goodFrameStreak >= 3
    }
}

extension CameraSetupModel: PoseEngineDelegate {
    nonisolated func poseEngine(_ engine: PoseEngine, didDetect frame: PoseFrame?) {
        Task { @MainActor [weak self] in self?.evaluate(frame: frame) }
    }
}

struct CameraSetupView: View {
    let configuration: PracticeConfiguration
    let onReady: () -> Void
    let onCancel: () -> Void
    /// Jump straight into the live session without framing guidance.
    let onSkip: () -> Void
    /// Switch to analyzing an existing video instead.
    let onUpload: () -> Void

    @Environment(AppState.self) private var appState
    @State private var model: CameraSetupModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let model {
                content(model: model)
            } else {
                ProgressView().tint(PUColor.lime)
            }
        }
        .task {
            let created = CameraSetupModel(handedness: appState.profile.handedness)
            model = created
            await created.start()
        }
        .onDisappear { model?.stop() }
    }

    @ViewBuilder
    private func content(model: CameraSetupModel) -> some View {
        switch model.camera.authorization {
        case .denied:
            PermissionDeniedView(onCancel: onCancel, onUpload: onUpload)
        case .noDeviceFound:
            NoCameraView(onCancel: onCancel, onUpload: onUpload)
        default:
            setupContent(model: model)
        }
    }

    private func setupContent(model: CameraSetupModel) -> some View {
        let tint = model.isIdeal ? PUColor.lime : PUColor.amber
        return ZStack(alignment: .top) {
            CameraPreviewView(session: model.camera.session)
                .ignoresSafeArea()

            PoseSkeletonOverlay(frame: model.currentPose, color: tint,
                                lineWidth: 2.5, jointRadius: 4)
                .ignoresSafeArea()

            FramingBrackets(isValid: model.isIdeal)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                guidanceBanner(model: model)
                checklistPanel(model: model)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PUColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .accessibilityLabel("Cancel setup")
            Spacer()
            Text("Camera Setup")
                .font(PUFont.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
            Spacer()
            Button {
                Haptics.tap()
                onSkip()
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PUColor.textPrimary)
                    .frame(minWidth: 40, minHeight: 40)
                    .padding(.horizontal, 6)
                    .background(.ultraThinMaterial, in: .capsule)
            }
            .accessibilityLabel("Skip camera setup")
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func guidanceBanner(model: CameraSetupModel) -> some View {
        let guidance = model.hasPlayer
            ? model.warnings.first?.guidance
            : "Step into the frame"
        Group {
            if let guidance {
                Text(guidance)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PUColor.limeInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(PUColor.amber, in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            } else if model.isIdeal {
                Text("Camera angle looks good")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PUColor.limeInk)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(PUColor.lime, in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: guidance)
    }

    private func checklistPanel(model: CameraSetupModel) -> some View {
        let hasWarnings = !model.warnings.isEmpty
        return VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      alignment: .leading, spacing: 9) {
                ForEach(model.checks) { check in
                    HStack(spacing: 8) {
                        Image(systemName: symbol(for: check.status))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(color(for: check.status))
                        Text(check.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(check.status == .passing ? PUColor.textPrimary : PUColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(check.status.description)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.checks.map(\.status.description))

            if hasWarnings {
                Label("Tracking quality may be reduced", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PUColor.amber)
                    .transition(.opacity)
            }

            Button(hasWarnings ? "START SESSION ANYWAY" : "START SESSION") {
                if hasWarnings { Haptics.warning() } else { Haptics.success() }
                onReady()
            }
            .buttonStyle(PUPrimaryButtonStyle(enabled: model.hasPlayer))
            .disabled(!model.hasPlayer)
            .animation(.easeInOut(duration: 0.2), value: hasWarnings)

            Text(model.hasPlayer
                 ? configurationSummary
                 : "Waiting for a player — or tap Skip to start without setup")
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [.clear, PUColor.canvasDeep.opacity(0.92), PUColor.canvasDeep],
                           startPoint: .top, endPoint: .bottom)
        )
        .animation(.easeInOut(duration: 0.2), value: hasWarnings)
    }

    private var configurationSummary: String {
        configuration.drill.map { "\($0.name) · \(configuration.length.displayName)" }
            ?? "\(configuration.shot.displayName) · \(configuration.length.displayName)"
    }

    private func symbol(for status: SetupCheck.Status) -> String {
        switch status {
        case .passing: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .pending: return "circle.dotted"
        }
    }

    private func color(for status: SetupCheck.Status) -> Color {
        switch status {
        case .passing: return PUColor.lime
        case .warning: return PUColor.amber
        case .pending: return PUColor.textTertiary
        }
    }
}

extension SetupCheck.Status {
    var description: String {
        switch self {
        case .pending: return "pending"
        case .warning: return "warning"
        case .passing: return "passing"
        }
    }
}

struct PermissionDeniedView: View {
    let onCancel: () -> Void
    var onUpload: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(PUColor.amber)
            Text("Camera access needed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PUColor.textPrimary)
            Text("Paddle Up analyses your body position from the camera to score each rep. Nothing is uploaded — analysis happens on your iPhone.")
                .font(PUFont.body)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("OPEN SETTINGS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PUPrimaryButtonStyle())
            if let onUpload {
                Button("UPLOAD A VIDEO INSTEAD", action: onUpload)
                    .buttonStyle(PUSecondaryButtonStyle())
            }
            Button("Not now", action: onCancel)
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
        }
        .padding(PUMetrics.margin * 1.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .puScreenBackground()
    }
}

struct NoCameraView: View {
    let onCancel: () -> Void
    var onUpload: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(PUColor.textTertiary)
            Text("No camera available")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PUColor.textPrimary)
            Text("Paddle Up couldn't find a camera on this device. Connect or enable a camera and try again.")
                .font(PUFont.body)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
            if let onUpload {
                Button("UPLOAD A VIDEO", action: onUpload)
                    .buttonStyle(PUPrimaryButtonStyle())
                Button("GO BACK", action: onCancel)
                    .buttonStyle(PUSecondaryButtonStyle())
            } else {
                Button("GO BACK", action: onCancel)
                    .buttonStyle(PUPrimaryButtonStyle())
            }
        }
        .padding(PUMetrics.margin * 1.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .puScreenBackground()
    }
}
