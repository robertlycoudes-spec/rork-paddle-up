//
//  VideoSessionAnalyzer.swift
//  PaddleUp
//
//  Runs an existing video through the same pipeline as a live session:
//
//    Decoded frames → PoseEngine → RepDetector → RepPipeline
//                   (ShotClassifier → MechanicsAnalyzer → ScoringEngine → CoachingEngine)
//
//  Frames are sampled at the live pose rate so the rep detector sees the same
//  cadence it was tuned on. Nothing is estimated: if the video can't be
//  decoded or no player is found, analysis fails with a clear reason.
//

import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import Vision

nonisolated struct VideoAnalysisProgress: Sendable, Equatable {
    enum Stage: Sendable, Equatable { case tracking, savingClips }

    var stage: Stage
    /// 0...1 through the current stage.
    var fraction: Double
    var repsFound: Int
}

nonisolated struct VideoAnalysisRequest: Sendable {
    let videoURL: URL
    let sessionID: UUID
    let shot: ShotType
    let hand: Handedness
    /// Where rep clips are written; nil when clip saving is off.
    let clipsDirectory: URL?
}

nonisolated struct VideoAnalysisResult: Sendable {
    let reps: [RepRecord]
    /// Wall-clock start assigned to the session (analysis time minus video length).
    let sessionStart: Date
    let videoDuration: TimeInterval
    let framesAnalyzed: Int
    let framesWithPlayer: Int

    /// Share of sampled frames that contained a trackable player.
    var playerCoverage: Double {
        framesAnalyzed > 0 ? Double(framesWithPlayer) / Double(framesAnalyzed) : 0
    }
}

nonisolated enum VideoAnalysisError: LocalizedError, Equatable {
    case unreadable
    case noVideoTrack
    case tooShort
    case tooLong(maxMinutes: Int)
    case decodeFailed
    case noPlayerFound

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "This video couldn't be opened. Try exporting it again or pick a different clip."
        case .noVideoTrack:
            return "This file doesn't contain any video."
        case .tooShort:
            return "This video is too short to analyze. Pick a clip with at least a few swings."
        case .tooLong(let maxMinutes):
            return "Videos can be up to \(maxMinutes) minutes long. Trim it in Photos and try again."
        case .decodeFailed:
            return "Paddle Up couldn't read the frames in this video. It may use an unsupported format."
        case .noPlayerFound:
            return "No player was found in this video. Make sure your body is clearly visible in the frame."
        }
    }
}

nonisolated enum VideoSessionAnalyzer {
    static let minimumDuration: TimeInterval = 1.5
    static let maximumDuration: TimeInterval = 30 * 60
    /// Matches the live pipeline: 30 fps camera, pose on every 2nd frame.
    static let poseFramesPerSecond: Double = 15

    /// Analyze a video off the main actor. Cancelling the calling task stops
    /// decoding promptly.
    static func analyze(_ request: VideoAnalysisRequest,
                        progress: @escaping @Sendable (VideoAnalysisProgress) -> Void) async throws -> VideoAnalysisResult {
        let task = Task.detached(priority: .userInitiated) {
            try await run(request, progress: progress)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - Pipeline

    private static func run(_ request: VideoAnalysisRequest,
                            progress: @escaping @Sendable (VideoAnalysisProgress) -> Void) async throws -> VideoAnalysisResult {
        let asset = AVURLAsset(url: request.videoURL)

        let track: AVAssetTrack
        let duration: TimeInterval
        let transform: CGAffineTransform
        do {
            guard let first = try await asset.loadTracks(withMediaType: .video).first else {
                throw VideoAnalysisError.noVideoTrack
            }
            track = first
            duration = try await asset.load(.duration).seconds
            transform = try await track.load(.preferredTransform)
        } catch let error as VideoAnalysisError {
            throw error
        } catch {
            throw VideoAnalysisError.unreadable
        }

        guard duration.isFinite, duration >= minimumDuration else { throw VideoAnalysisError.tooShort }
        guard duration <= maximumDuration else {
            throw VideoAnalysisError.tooLong(maxMinutes: Int(maximumDuration / 60))
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw VideoAnalysisError.unreadable
        }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw VideoAnalysisError.decodeFailed }
        reader.add(output)
        guard reader.startReading() else { throw VideoAnalysisError.decodeFailed }

        let orientation = orientation(for: transform)
        let sessionStart = Date().addingTimeInterval(-duration)
        let detector = RepDetector(hand: request.hand)
        let poseRequest = VNDetectHumanBodyPoseRequest()
        poseRequest.revision = VNDetectHumanBodyPoseRequestRevision1

        var reps: [RepRecord] = []
        var repEndTimes: [TimeInterval] = []
        var framesAnalyzed = 0
        var framesWithPlayer = 0
        var firstTimestamp: Double?
        var lastSampled = -Double.infinity
        var lastReported = -1.0
        let interval = 1.0 / poseFramesPerSecond

        progress(VideoAnalysisProgress(stage: .tracking, fraction: 0, repsFound: 0))

        while reader.status == .reading {
            if Task.isCancelled {
                reader.cancelReading()
                throw CancellationError()
            }
            guard let sample = output.copyNextSampleBuffer() else { break }

            let presentation = CMSampleBufferGetPresentationTimeStamp(sample).seconds
            guard presentation.isFinite else { continue }
            let origin = firstTimestamp ?? presentation
            firstTimestamp = origin
            let time = presentation - origin

            // Sample at the live pose cadence (small tolerance for timestamp jitter).
            guard time - lastSampled >= interval * 0.95 else { continue }
            lastSampled = time
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }

            framesAnalyzed += 1
            let pose = autoreleasepool {
                PoseEngine.detectPose(in: pixelBuffer, orientation: orientation,
                                      time: time, using: poseRequest)
            }

            if let pose {
                if SetupCheckEvaluator.hasPlayer(pose) { framesWithPlayer += 1 }
                if case .repCompleted(let window) = detector.ingest(pose) {
                    let endTime = window.frames.last?.time ?? time
                    let outcome = RepPipeline.process(
                        window: window, expected: request.shot, hand: request.hand,
                        sessionID: request.sessionID, index: reps.count + 1,
                        timestamp: sessionStart.addingTimeInterval(endTime)
                    )
                    if let scored = outcome.scored {
                        reps.append(scored.rep)
                        repEndTimes.append(origin + endTime)
                    }
                }
            }

            let fraction = min(1, time / duration)
            if fraction - lastReported >= 0.01 {
                lastReported = fraction
                progress(VideoAnalysisProgress(stage: .tracking, fraction: fraction, repsFound: reps.count))
            }
        }

        if reader.status == .failed { throw VideoAnalysisError.decodeFailed }
        guard framesAnalyzed > 0 else { throw VideoAnalysisError.decodeFailed }
        guard framesWithPlayer > 0 else { throw VideoAnalysisError.noPlayerFound }

        // Cut the same ~3s clip around each rep a live session would keep.
        if let directory = request.clipsDirectory, !reps.isEmpty {
            for index in reps.indices {
                if Task.isCancelled { throw CancellationError() }
                progress(VideoAnalysisProgress(stage: .savingClips,
                                               fraction: Double(index) / Double(reps.count),
                                               repsFound: reps.count))
                let end = min(duration, repEndTimes[index] + 0.4)
                let start = max(0, repEndTimes[index] - 3.0)
                let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                        end: CMTime(seconds: end, preferredTimescale: 600))
                reps[index].clipFilename = await exportClip(asset: asset, range: range, directory: directory)
            }
        }

        progress(VideoAnalysisProgress(stage: reps.isEmpty ? .tracking : .savingClips,
                                       fraction: 1, repsFound: reps.count))

        return VideoAnalysisResult(reps: reps, sessionStart: sessionStart, videoDuration: duration,
                                   framesAnalyzed: framesAnalyzed, framesWithPlayer: framesWithPlayer)
    }

    private static func exportClip(asset: AVURLAsset, range: CMTimeRange, directory: URL) async -> String? {
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540) else {
            return nil
        }
        let filename = "rep-\(UUID().uuidString).mp4"
        let url = directory.appendingPathComponent(filename)
        export.timeRange = range
        do {
            try await export.export(to: url, as: .mp4)
            return filename
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Vision orientation that renders the track upright, from its display transform.
    static func orientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
        let a = transform.a.rounded(), b = transform.b.rounded()
        let c = transform.c.rounded(), d = transform.d.rounded()
        if a == 0 && b == 1 && c == -1 && d == 0 { return .right }
        if a == 0 && b == -1 && c == 1 && d == 0 { return .left }
        if a == -1 && b == 0 && c == 0 && d == -1 { return .down }
        return .up
    }
}
