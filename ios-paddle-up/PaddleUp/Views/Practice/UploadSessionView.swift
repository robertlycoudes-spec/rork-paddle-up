//
//  UploadSessionView.swift
//  PaddleUp
//
//  Pick a video from Photos, analyze it with the live pipeline, and hand the
//  finished session to the standard summary. Failures are reported honestly —
//  no rep is ever invented for a video that couldn't be read.
//

import PhotosUI
import SwiftUI

struct UploadSessionView: View {
    let configuration: PracticeConfiguration
    let onBack: () -> Void
    let onFinished: (UUID) -> Void

    @Environment(AppState.self) private var appState
    @State private var model = UploadAnalysisModel()
    @State private var selection: PhotosPickerItem?
    @State private var showingPicker = false
    @State private var hasPicked = false
    @State private var hasAutoPresented = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 12)
            content
            Spacer(minLength: 12)
            bottomActions
        }
        .padding(.horizontal, PUMetrics.margin)
        .puScreenBackground()
        .photosPicker(isPresented: $showingPicker, selection: $selection,
                      matching: .videos, preferredItemEncoding: .current)
        .onChange(of: selection) { _, item in
            guard let item else { return }
            hasPicked = true
            model.start(item: item, configuration: configuration, appState: appState)
            selection = nil
        }
        .onChange(of: model.phase) { _, phase in
            if case .finished(let id) = phase { onFinished(id) }
        }
        .onAppear {
            guard !hasAutoPresented else { return }
            hasAutoPresented = true
            showingPicker = true
        }
        .onDisappear { model.cancel() }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button {
                model.cancel()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PUColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(PUColor.surfaceRaised, in: .circle)
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Upload Video")
                .font(PUFont.headline)
                .foregroundStyle(PUColor.textPrimary)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if !hasPicked {
            intro
        } else {
            switch model.phase {
            case .importing:
                progressPanel(title: "Loading video…", fraction: nil,
                              detail: "Copying the clip from your library.")
            case .analyzing, .finished:
                progressPanel(title: progressTitle, fraction: model.progress.fraction,
                              detail: progressDetail)
            case .failed(let message):
                messagePanel(symbol: "exclamationmark.triangle.fill", tint: PUColor.alert,
                             title: "Couldn't analyze this video", message: message)
            case .noReps(let coverage):
                messagePanel(symbol: "figure.pickleball", tint: PUColor.amber,
                             title: "No complete swings found",
                             message: noRepsMessage(coverage: coverage))
            }
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: 10) {
            if showsChooseButton {
                Button {
                    Haptics.tap()
                    showingPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(hasPicked ? "CHOOSE ANOTHER VIDEO" : "CHOOSE VIDEO")
                    }
                }
                .buttonStyle(PUPrimaryButtonStyle())
            } else if isWorking {
                Button("CANCEL") {
                    model.cancel()
                    hasPicked = false
                }
                .buttonStyle(PUSecondaryButtonStyle())
            }
            Text(summaryLine)
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textSecondary)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Panels

    private var intro: some View {
        VStack(spacing: 18) {
            PUIconBadge(symbol: "film.stack", size: 72)
            Text("Analyze a clip from your library")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PUColor.textPrimary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                tip("figure.stand", "Your whole body visible, filmed from the side or behind")
                tip("iphone", "Phone held still — a tripod or fence works best")
                tip("timer", "Up to 30 minutes. Longer clips take longer to analyze")
                tip("lock.fill", "Analyzed on your iPhone. The video is never uploaded")
            }
            .padding(16)
            .background(PUColor.surface, in: .rect(cornerRadius: PUMetrics.cardRadius))
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PUColor.lime)
                .frame(width: 20)
            Text(text)
                .font(PUFont.caption)
                .foregroundStyle(PUColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func progressPanel(title: String, fraction: Double?, detail: String) -> some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 12)
                if let fraction {
                    Circle()
                        .trim(from: 0, to: max(0.01, fraction))
                        .stroke(PUColor.lime, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: fraction)
                    VStack(spacing: 2) {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.system(size: 40, weight: .heavy).monospacedDigit())
                            .foregroundStyle(PUColor.textPrimary)
                            .contentTransition(.numericText())
                        Text("\(model.progress.repsFound) reps")
                            .font(PUFont.caption.monospacedDigit())
                            .foregroundStyle(PUColor.lime)
                            .contentTransition(.numericText())
                    }
                } else {
                    ProgressView().tint(PUColor.lime).controlSize(.large)
                }
            }
            .frame(width: 180, height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(fraction.map { "\(Int($0 * 100)) percent" } ?? "")

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PUColor.textPrimary)
                Text(detail)
                    .font(PUFont.caption)
                    .foregroundStyle(PUColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func messagePanel(symbol: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PUColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(PUFont.body)
                .foregroundStyle(PUColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Copy

    private var isWorking: Bool {
        guard hasPicked else { return false }
        return model.phase == .importing || model.phase == .analyzing
    }

    private var showsChooseButton: Bool {
        guard hasPicked else { return true }
        switch model.phase {
        case .failed, .noReps: return true
        default: return false
        }
    }

    private var progressTitle: String {
        model.progress.stage == .savingClips ? "Saving rep clips…" : "Analyzing your swings…"
    }

    private var progressDetail: String {
        model.progress.stage == .savingClips
            ? "Cutting a short replay for each rep."
            : "Tracking your body, detecting reps and scoring mechanics."
    }

    private var summaryLine: String {
        let what = configuration.drill?.name ?? configuration.shot.displayName
        return "\(configuration.mode.displayName) · \(what)"
    }

    private func noRepsMessage(coverage: Double) -> String {
        if coverage < 0.3 {
            return "You were only visible in \(Int(coverage * 100))% of the video. Film with your whole body in frame and the phone held still."
        }
        return "Paddle Up tracked you but didn't see a full \(configuration.shot.displayName.lowercased()) swing. Try a clip where you hit several shots in a row."
    }
}
