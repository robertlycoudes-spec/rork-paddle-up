//
//  UploadAnalysisModel.swift
//  PaddleUp
//
//  Drives one uploaded-video session: import from Photos → analyze → save.
//  Saves exactly like a live session so the summary, history, progress and
//  plan all treat it the same way.
//

import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class UploadAnalysisModel {
    enum Phase: Equatable {
        case importing
        case analyzing
        case failed(String)
        /// Video decoded and a player was tracked, but no complete swing was found.
        case noReps(playerCoverage: Double)
        case finished(UUID)
    }

    private(set) var phase: Phase = .importing
    private(set) var progress = VideoAnalysisProgress(stage: .tracking, fraction: 0, repsFound: 0)
    private var task: Task<Void, Never>?

    func start(item: PhotosPickerItem, configuration: PracticeConfiguration, appState: AppState) {
        task?.cancel()
        phase = .importing
        progress = VideoAnalysisProgress(stage: .tracking, fraction: 0, repsFound: 0)
        task = Task { await run(item: item, configuration: configuration, appState: appState) }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func run(item: PhotosPickerItem, configuration: PracticeConfiguration, appState: AppState) async {
        let movie: PickedMovie
        do {
            guard let loaded = try await item.loadTransferable(type: PickedMovie.self) else {
                phase = .failed("That item isn't a video Paddle Up can read. Pick a different clip.")
                return
            }
            movie = loaded
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed("Couldn't load that video from your library. If it's stored in iCloud, check your connection and try again.")
            return
        }
        defer { try? FileManager.default.removeItem(at: movie.url) }
        guard !Task.isCancelled else { return }

        phase = .analyzing
        var session = SessionRecord(startedAt: .now, shot: configuration.shot, mode: configuration.mode,
                                    drillID: configuration.drillID, focusCue: configuration.drill?.focusCue)
        let request = VideoAnalysisRequest(
            videoURL: movie.url,
            sessionID: session.id,
            shot: configuration.shot,
            hand: appState.profile.handedness,
            clipsDirectory: appState.settings.saveRepClips ? appState.clipsDirectory : nil
        )
        let isAssessment = configuration.mode == .assessment
        appState.analytics.record(isAssessment ? .assessmentStarted : .practiceStarted,
                                  properties: ["shot": configuration.shot.rawValue,
                                               "mode": configuration.mode.rawValue,
                                               "source": "upload"])

        do {
            let result = try await VideoSessionAnalyzer.analyze(request) { update in
                Task { @MainActor in
                    guard self.phase == .analyzing else { return }
                    self.progress = update
                }
            }
            guard !Task.isCancelled else { return }

            guard !result.reps.isEmpty else {
                phase = .noReps(playerCoverage: result.playerCoverage)
                return
            }

            session.startedAt = result.sessionStart
            session.endedAt = result.sessionStart.addingTimeInterval(result.videoDuration)
            session.reps = result.reps
            appState.save(session: session)
            appState.analytics.record(isAssessment ? .assessmentCompleted : .practiceCompleted,
                                      properties: ["shot": configuration.shot.rawValue,
                                                   "reps": String(result.reps.count),
                                                   "source": "upload"])
            if configuration.mode == .drill {
                appState.analytics.record(.drillCompleted, properties: ["drill": configuration.drillID ?? ""])
            }
            Haptics.success()
            phase = .finished(session.id)
        } catch is CancellationError {
            return
        } catch let error as VideoAnalysisError {
            Haptics.warning()
            phase = .failed(error.errorDescription ?? "This video couldn't be analyzed.")
        } catch {
            Haptics.warning()
            phase = .failed("Something went wrong while analyzing this video. Please try another clip.")
        }
    }
}
