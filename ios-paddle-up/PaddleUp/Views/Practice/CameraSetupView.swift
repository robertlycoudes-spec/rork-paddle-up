//
//  CameraSetupView.swift
//  PaddleUp
//
//  Pre-practice framing check with live guidance. Runs the real camera and
//  pose pipeline so the checks reflect what the analyzer will actually see.
//

import AVFoundation
import SwiftUI

/// One framing requirement evaluated live from the pose stream.
nonisolated struct SetupCheck: Identifiable, Sendable {
    enum Status: Sendable { case pending, warning, passing }

    let id: String
    let title: String
    let status: Status
    /// Live guidance shown when the check isn't passing.
    let guidance: String?
}

@MainActor
@Observable
final class CameraSetupModel: NSObject {
    let camera = CameraService()
    private let pose = PoseEngine(frameStride: 3)

    private(set) var currentPose: PoseFrame?
    private(set) var checks: [SetupCheck] = []
    private(set) var isReady = false
    /// Consecutive good frames, so a single lucky frame doesn't unlock start.
    private var goodFrameStreak = 0
    private var recentCenters: [CGPoint] = []
    private var lastEvaluation: Date = .distantPast

    private let handedness: Handedness

    init(handedness: Handedness) {
        self.handedness = handedness
        super.init()
        checks = Self.pendingChecks()
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

    private static func pendingChecks() -> [SetupCheck] {
        [
            SetupCheck(id: "player", title: "Player detected", status: .pending, guidance: "Step into frame"),
            SetupCheck(id: "fullBody", title: "Full body visible", status: .pending, guidance: nil),
            SetupCheck(id: "distance", title: "Far enough away", status: .pending, guidance: nil),
            SetupCheck(id: "stable", title: "Camera stable", status: .pending, guidance: nil),
            SetupCheck(id: "lighting", title: "Lighting acceptable", status: .pending, guidance: nil),
            SetupCheck(id: "orientation", title: "Orientation correct", status: .pending, guidance: nil)
        ]
    }

    fileprivate func evaluate(frame: PoseFrame?) {
        currentPose = frame

        // Throttle recomputation so guidance text doesn't flicker.
        guard Date().timeIntervalSince(lastEvaluation) > 0.2 else { return }
        lastEvaluation = .now

        guard let frame, frame.meanConfidence > 0.15 else {
            checks = Self.pendingChecks()
            goodFrameStreak = 0
            isReady = false
            return
        }

        var results: [SetupCheck] = []

        // 1. Player detected
        let detected = frame.meanConfidence > 0.3
        results.append(SetupCheck(id: "player", title: "Player detected",
                                  status: detected ? .passing : .warning,
                                  guidance: detected ? nil : "Step into the frame"))

        // 2. Full body visible — need ankles and head inside the frame.
        let hasFeet = frame.point(.leftAnkle, minConfidence: 0.2) != nil
            || frame.point(.rightAnkle, minConfidence: 0.2) != nil
        let hasHead = frame.point(.nose, minConfidence: 0.2) != nil
        let coverage = frame.framingCoverage
        let fullBody = hasFeet && hasHead && coverage > 0.88
        var bodyGuidance: String?
        if !hasFeet { bodyGuidance = "Your feet are outside the frame" }
        else if !hasHead { bodyGuidance = "Tilt the camera down — your head is cut off" }
        else if coverage <= 0.88 { bodyGuidance = "Part of you is out of frame" }
        results.append(SetupCheck(id: "fullBody", title: "Full body visible",
                                  status: fullBody ? .passing : .warning, guidance: bodyGuidance))

        // 3. Distance — judged by how much of the frame height the body fills.
        let bodyHeight = bodyHeightFraction(frame)
        let distanceOK = bodyHeight > 0.32 && bodyHeight < 0.92
        var distanceGuidance: String?
        if bodyHeight >= 0.92 { distanceGuidance = "Move farther back" }
        else if bodyHeight <= 0.32 { distanceGuidance = "Move closer to the camera" }
        results.append(SetupCheck(id: "distance", title: "Far enough away",
                                  status: distanceOK ? .passing : .warning, guidance: distanceGuidance))

        // 4. Camera stability — the whole skeleton shifting frame-to-frame
        //    while the player stands still means the phone is moving.
        if let center = frame.hipCenter {
            recentCenters.append(center)
            if recentCenters.count > 12 { recentCenters.removeFirst() }
        }
        let jitter = centerJitter()
        let stable = recentCenters.count < 6 || jitter < 0.05
        results.append(SetupCheck(id: "stable", title: "Camera stable",
                                  status: stable ? .passing : .warning,
                                  guidance: stable ? nil : "Prop the phone against something solid"))

        // 5. Lighting — low light collapses joint confidence.
        let lighting = frame.meanConfidence > 0.45
        results.append(SetupCheck(id: "lighting", title: "Lighting acceptable",
                                  status: lighting ? .passing : .warning,
                                  guidance: lighting ? nil : "Too dark — find brighter light"))

        // 6. Orientation — the body should read as upright in portrait.
        let upright = isUpright(frame)
        results.append(SetupCheck(id: "orientation", title: "Orientation correct",
                                  status: upright ? .passing : .warning,
                                  guidance: upright ? nil : "Stand the phone upright in portrait"))

        checks = results

        let allPassing = results.allSatisfy { $0.status == .passing }
        goodFrameStreak = allPassing ? goodFrameStreak + 1 : 0
        isReady = goodFrameStreak >= 4
    }

    private func bodyHeightFraction(_ frame: PoseFrame) -> Double {
        let ys = frame.joints.values.filter { $0.confidence > 0.2 }.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max() else { return 0 }
        return maxY - minY
    }

    private func centerJitter() -> Double {
        guard recentCenters.count > 2 else { return 0 }
        let xs = recentCenters.map(\.x), ys = recentCenters.map(\.y)
        return hypot((xs.max() ?? 0) - (xs.min() ?? 0), (ys.max() ?? 0) - (ys.min() ?? 0))
    }

    private func isUpright(_ frame: PoseFrame) -> Bool {
        guard let shoulders = frame.shoulderCenter, let hips = frame.hipCenter else { return true }
        // Torso should be taller than it is wide in screen space.
        return abs(hips.y - shoulders.y) > abs(hips.x - shoulders.x)
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
            PermissionDeniedView(onCancel: onCancel)
        case .noDeviceFound:
            NoCameraView(onCancel: onCancel)
        default:
            setupContent(model: model)
        }
    }

    private func setupContent(model: CameraSetupModel) -> some View {
        ZStack(alignment: .top) {
            CameraPreviewView(session: model.camera.session)
                .ignoresSafeArea()

            PoseSkeletonOverlay(frame: model.currentPose,
                                color: model.isReady ? PUColor.lime : PUColor.amber,
                                lineWidth: 2.5, jointRadius: 4)
                .ignoresSafeArea()

            FramingBrackets(isValid: model.isReady)
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
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func guidanceBanner(model: CameraSetupModel) -> some View {
        let guidance = model.checks.first { $0.status != .passing }?.guidance
        if let guidance {
            Text(guidance)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PUColor.limeInk)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(PUColor.amber, in: .capsule)
                .padding(.bottom, 12)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: guidance)
        } else if model.isReady {
            Text("Camera angle looks good")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PUColor.limeInk)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(PUColor.lime, in: .capsule)
                .padding(.bottom, 12)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func checklistPanel(model: CameraSetupModel) -> some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      alignment: .leading, spacing: 9) {
                ForEach(model.checks) { check in
                    HStack(spacing: 8) {
                        Image(systemName: check.status == .passing ? "checkmark.circle.fill"
                                                                   : "circle.dotted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(check.status == .passing ? PUColor.lime : PUColor.textTertiary)
                        Text(check.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(check.status == .passing ? PUColor.textPrimary : PUColor.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.checks.map(\.status.description))

            Button("START SESSION") {
                Haptics.success()
                onReady()
            }
            .buttonStyle(PUPrimaryButtonStyle(enabled: model.isReady))
            .disabled(!model.isReady)

            Text(configuration.drill.map { "\($0.name) · \(configuration.length.displayName)" }
                 ?? "\(configuration.shot.displayName) · \(configuration.length.displayName)")
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .background(
            LinearGradient(colors: [.clear, PUColor.canvasDeep.opacity(0.92), PUColor.canvasDeep],
                           startPoint: .top, endPoint: .bottom)
        )
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
            Button("GO BACK", action: onCancel)
                .buttonStyle(PUPrimaryButtonStyle())
        }
        .padding(PUMetrics.margin * 1.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .puScreenBackground()
    }
}
