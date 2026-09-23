//
//  PracticeEngine.swift
//  PaddleUp
//
//  Orchestrates the live pipeline for one session:
//
//    Camera → PoseEngine → RepDetector → ShotClassifier
//           → MechanicsAnalyzer → ScoringEngine → CoachingEngine
//
//  Each stage is a separate type; this class only wires them together and holds
//  the live session state the UI observes. Core logic is never buried here.
//

import AVFoundation
import Foundation
import Observation
import QuartzCore
import SwiftUI

/// What the live UI needs to render after each rep.
nonisolated struct LiveRepFeedback: Sendable, Identifiable {
    let id = UUID()
    let rep: RepRecord
    let coaching: RepCoaching
}

@MainActor
@Observable
final class PracticeEngine: NSObject {
    // Injected collaborators
    let camera = CameraService()
    private let pose = PoseEngine()
    private let voice = VoiceCoach()
    private var detector: RepDetector
    private var clipRecorder: ClipRecorder?

    private weak var appState: AppState?

    // Configuration
    private(set) var shot: ShotType
    private(set) var mode: SessionMode
    private(set) var drill: Drill?
    private(set) var length: SessionLength
    private let hand: Handedness

    // Live session state
    private(set) var session: SessionRecord
    private(set) var latestFeedback: LiveRepFeedback?
    private(set) var repCount: Int = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var isFinished = false
    private(set) var currentCue: String
    /// Most recent detected pose, for the skeleton overlay.
    private(set) var currentPose: PoseFrame?

    // Developer-mode readouts
    private(set) var detectorState: RepState = .idle
    private(set) var lastRejection: RepRejection?
    private(set) var liveWristSpeed: Double = 0
    private(set) var lastClassificationConfidence: Double = 0

    private var timer: Timer?
    private var startMediaTime: CFTimeInterval = 0
    private var pendingClipTasks: Int = 0

    var targetSeconds: TimeInterval? { length.seconds }
    var progress: Double {
        guard let target = targetSeconds, target > 0 else { return 0 }
        return min(1, elapsed / target)
    }

    init(shot: ShotType, mode: SessionMode, drill: Drill?, length: SessionLength,
         appState: AppState) {
        self.shot = shot
        self.mode = mode
        self.drill = drill
        self.length = length
        self.appState = appState
        self.hand = appState.profile.handedness
        self.detector = RepDetector(hand: appState.profile.handedness)
        self.currentCue = drill?.focusCue ?? "SETTLE IN"
        self.session = SessionRecord(startedAt: .now, shot: shot, mode: mode,
                                     drillID: drill?.id, focusCue: drill?.focusCue)
        super.init()

        voice.level = appState.settings.voiceCoaching
        if appState.settings.saveRepClips, let directory = appState.clipsDirectory {
            let recorder = ClipRecorder(outputDirectory: directory)
            recorder.isEnabled = true
            self.clipRecorder = recorder
        }
    }

    // MARK: - Lifecycle

    func begin() async {
        pose.delegate = self
        voice.configureAudioSession()
        // Capture the nonisolated collaborators directly: the sample handler is
        // invoked on the camera's capture queue, never the main actor.
        let poseEngine = pose
        let recorder = clipRecorder
        camera.sampleHandler = { buffer in
            poseEngine.process(sampleBuffer: buffer, orientation: .right)
            recorder?.ingest(sampleBuffer: buffer, now: CACurrentMediaTime())
        }
        await camera.start()
        startMediaTime = CACurrentMediaTime()
        startTimer()
        appState?.analytics.record(mode == .assessment ? .assessmentStarted : .practiceStarted,
                                   properties: ["shot": shot.rawValue, "mode": mode.rawValue])
    }

    func end() {
        guard !isFinished else { return }
        isFinished = true
        timer?.invalidate()
        timer = nil
        camera.sampleHandler = nil
        camera.stop()
        voice.deactivate()
        session.endedAt = .now
        appState?.save(session: session)
        appState?.analytics.record(mode == .assessment ? .assessmentCompleted : .practiceCompleted,
                                   properties: ["shot": shot.rawValue, "reps": String(repCount)])
        if mode == .drill { appState?.analytics.record(.drillCompleted, properties: ["drill": drill?.id ?? ""]) }
    }

    func teardown() {
        timer?.invalidate()
        camera.sampleHandler = nil
        camera.stop()
        voice.deactivate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard !isFinished else { return }
        elapsed = CACurrentMediaTime() - startMediaTime
        if let target = targetSeconds, elapsed >= target {
            end()
        }
    }

    // MARK: - Pipeline

    private func handle(window: RepWindow) {
        // Classify → measure → score → coach, shared with uploaded-video analysis.
        let outcome = RepPipeline.process(window: window, expected: shot, hand: hand,
                                          sessionID: session.id, index: repCount + 1, timestamp: .now)
        lastClassificationConfidence = outcome.classificationConfidence
        guard let scored = outcome.scored else { return }

        repCount += 1
        var rep = scored.rep
        let coaching = scored.coaching
        let analysisScore = rep.score

        currentCue = coaching.cue
        let feedback = LiveRepFeedback(rep: rep, coaching: coaching)
        latestFeedback = feedback

        Haptics.repDetected(score: analysisScore)
        voice.handle(coaching: coaching, repIndex: repCount)
        appState?.analytics.record(.repDetected, properties: [
            "shot": rep.shot.rawValue, "score": String(Int(analysisScore))
        ])

        // Persist the rep immediately so a crash never loses practice data.
        session.reps.append(rep)
        appState?.save(session: session)

        // Encode the short clip asynchronously, then attach it to the rep.
        if let recorder = clipRecorder {
            let endTime = window.frames.last?.time ?? elapsed
            let mediaEnd = startMediaTime + endTime
            pendingClipTasks += 1
            Task { [weak self] in
                let filename = await recorder.saveClip(around: mediaEnd)
                await MainActor.run {
                    guard let self else { return }
                    self.pendingClipTasks -= 1
                    guard let filename,
                          let index = self.session.reps.firstIndex(where: { $0.id == rep.id }) else { return }
                    self.session.reps[index].clipFilename = filename
                    rep.clipFilename = filename
                    self.appState?.save(session: self.session)
                }
            }
        }
    }
}

extension PracticeEngine: PoseEngineDelegate {
    nonisolated func poseEngine(_ engine: PoseEngine, didDetect frame: PoseFrame?) {
        Task { @MainActor [weak self] in
            guard let self, !self.isFinished else { return }
            guard let frame else { return }
            self.currentPose = frame

            let event = self.detector.ingest(frame)
            self.detectorState = self.detector.state
            self.liveWristSpeed = self.detector.lastWristSpeed

            switch event {
            case .repCompleted(let window):
                self.handle(window: window)
            case .repRejected(let reason):
                self.lastRejection = reason
                self.appState?.analytics.record(.repRejected, properties: ["reason": reason.rawValue])
            case .stateChanged, .none:
                break
            }
        }
    }
}
