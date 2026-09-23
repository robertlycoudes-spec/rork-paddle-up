//
//  LivePracticeView.swift
//  PaddleUp
//
//  The signature screen: continuous camera with pose overlay on top, and the
//  most recent rep's Score → Main Issue → Fix → Next Focus stacked below.
//

import SwiftUI

struct PracticeSetupFlow: View {
    let configuration: PracticeConfiguration

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router
    @State private var phase: Phase = .chooseSource

    private enum Phase: Equatable { case chooseSource, setup, live, upload }

    var body: some View {
        Group {
            switch phase {
            case .chooseSource:
                SessionSourcePickerView(
                    configuration: configuration,
                    onRecordLive: { go(.setup) },
                    onUpload: { go(.upload) },
                    onCancel: { router.activeConfiguration = nil }
                )
            case .setup:
                CameraSetupView(
                    configuration: configuration,
                    onReady: { go(.live) },
                    onCancel: { go(.chooseSource) },
                    onSkip: { go(.live) },
                    onUpload: { go(.upload) }
                )
            case .live:
                LivePracticeView(configuration: configuration)
            case .upload:
                UploadSessionView(
                    configuration: configuration,
                    onBack: { go(.chooseSource) },
                    onFinished: { sessionID in
                        router.activeConfiguration = nil
                        router.completedSessionID = sessionID
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func go(_ next: Phase) {
        withAnimation(.easeInOut(duration: 0.25)) { phase = next }
    }
}

struct LivePracticeView: View {
    let configuration: PracticeConfiguration

    @Environment(AppState.self) private var appState
    @Environment(PracticeRouter.self) private var router

    @State private var engine: PracticeEngine?
    @State private var showingEndConfirmation = false
    @State private var showingDeveloperPanel = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let engine {
                content(engine: engine)
            } else {
                ProgressView().tint(PUColor.lime)
            }
        }
        .task {
            guard engine == nil else { return }
            let created = PracticeEngine(
                shot: configuration.shot,
                mode: configuration.mode,
                drill: configuration.drill,
                length: configuration.length,
                appState: appState
            )
            engine = created
            await created.begin()
        }
        .onDisappear { engine?.teardown() }
        .onChange(of: engine?.isFinished ?? false) { _, finished in
            guard finished, let engine else { return }
            let sessionID = engine.session.id
            router.activeConfiguration = nil
            router.completedSessionID = sessionID
        }
    }

    private func content(engine: PracticeEngine) -> some View {
        VStack(spacing: 0) {
            cameraPane(engine: engine)
            feedbackPane(engine: engine)
        }
        .ignoresSafeArea(edges: .bottom)
        .confirmationDialog("End this session?", isPresented: $showingEndConfirmation, titleVisibility: .visible) {
            Button("End session", role: .destructive) { engine.end() }
            Button("Keep practising", role: .cancel) {}
        } message: {
            Text("\(engine.repCount) reps recorded so far.")
        }
        .sheet(isPresented: $showingDeveloperPanel) {
            DeveloperPanelView(engine: engine)
        }
    }

    // MARK: - Camera pane

    private func cameraPane(engine: PracticeEngine) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if engine.camera.authorization == .authorized {
                    CameraPreviewView(session: engine.camera.session)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    PUColor.canvasDeep
                }

                PoseSkeletonOverlay(frame: engine.currentPose, lineWidth: 3, jointRadius: 5)

                FramingBrackets(isValid: true)
                    .opacity(0.55)

                VStack {
                    liveTopBar(engine: engine)
                    Spacer()
                    if let target = engine.targetSeconds, target > 0 {
                        sessionProgressBar(engine: engine)
                    }
                    cueBanner(engine: engine)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func liveTopBar(engine: PracticeEngine) -> some View {
        HStack(spacing: 10) {
            Button { showingEndConfirmation = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .accessibilityLabel("End session")

            Spacer()

            if appState.settings.developerModeEnabled {
                Button { showingDeveloperPanel = true } label: {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PUColor.amber)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .accessibilityLabel("Developer panel")
            }

            HStack(spacing: 6) {
                Text("Rep").font(.system(size: 13, weight: .medium)).foregroundStyle(PUColor.textSecondary)
                Text("\(engine.repCount)")
                    .font(.system(size: 17, weight: .bold).monospacedDigit())
                    .foregroundStyle(PUColor.lime)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(.ultraThinMaterial, in: .capsule)

            HStack(spacing: 6) {
                Image(systemName: "timer").font(.system(size: 12, weight: .semibold))
                Text(timeString(engine.elapsed))
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(.ultraThinMaterial, in: .capsule)
        }
    }

    private func sessionProgressBar(engine: PracticeEngine) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.35))
                Capsule().fill(PUColor.lime).frame(width: geo.size.width * engine.progress)
            }
        }
        .frame(height: 3)
        .padding(.bottom, 10)
        .animation(.linear(duration: 0.25), value: engine.progress)
    }

    @ViewBuilder
    private func cueBanner(engine: PracticeEngine) -> some View {
        if engine.repCount == 0 {
            Text(detectorHint(engine: engine))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: .capsule)
                .transition(.opacity)
        }
    }

    private func detectorHint(engine: PracticeEngine) -> String {
        if engine.currentPose == nil { return "Looking for you…" }
        return "Ready — start hitting"
    }

    // MARK: - Feedback pane

    private func feedbackPane(engine: PracticeEngine) -> some View {
        VStack(spacing: 10) {
            if let feedback = engine.latestFeedback {
                scoreCard(feedback: feedback)
                correctionCard(feedback: feedback)
            } else {
                waitingCard(engine: engine)
            }

            Button { showingEndConfirmation = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "stop.fill")
                    Text("End Session")
                }
            }
            .buttonStyle(PUPrimaryButtonStyle())
        }
        .padding(.horizontal, PUMetrics.margin)
        .padding(.top, 14)
        .padding(.bottom, 34)
        .background(PUColor.canvas)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: engine.latestFeedback?.id)
    }

    private func scoreCard(feedback: LiveRepFeedback) -> some View {
        PUCard(padding: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paddle Up Score").puMicroLabel()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(feedback.rep.score))")
                            .font(.system(size: 52, weight: .heavy).monospacedDigit())
                            .foregroundStyle(PUColor.textPrimary)
                            .contentTransition(.numericText())
                        Text("/ 100")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PUColor.textSecondary)
                    }
                    if feedback.rep.confidence < 0.55 {
                        Label("Low confidence read", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PUColor.amber)
                    }
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: feedback.rep.score / 100)
                        .stroke(PUColor.score(feedback.rep.score),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    PUBallGlyph(size: 20)
                }
                .frame(width: 84, height: 84)
            }
        }
    }

    private func correctionCard(feedback: LiveRepFeedback) -> some View {
        PUCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feedback.coaching.isPraise ? "checkmark.seal.fill" : "scope")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(feedback.coaching.isPraise ? PUColor.lime : PUColor.alert)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feedback.coaching.isPraise ? "Good rep" : "Main issue").puMicroLabel()
                        Text(feedback.coaching.headline)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(PUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider().overlay(PUColor.hairline)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PUColor.lime)
                        .frame(width: 26)
                    Text(feedback.coaching.correction)
                        .font(PUFont.body)
                        .foregroundStyle(PUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next rep focus").puMicroLabel()
                        Text(feedback.coaching.cue)
                            .font(.system(size: 16, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(PUColor.lime)
                    }
                    Spacer()
                }
                .padding(12)
                .background(PUColor.limeDim, in: .rect(cornerRadius: 12))
            }
        }
    }

    private func waitingCard(engine: PracticeEngine) -> some View {
        PUCard(padding: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(configuration.drill?.focusCue.uppercased() ?? "FOCUS").puMicroLabel()
                Text(configuration.drill?.focusCue ?? "Hit naturally — Paddle Up will find your reps.")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(PUColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your first scored rep will appear here.")
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
            }
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
