//
//  VideoSessionAnalyzer.swift
//  PaddleUp
//
//  Runs an existing video through the same pipeline as a live session:
//
//    Decoded frames → PoseEngine → PoseStreamProcessor (track + smooth)
//                   → paddle-hand check → RepDetector → RepPipeline
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
    /// The arm that was analyzed as the paddle arm.
    let analyzedHand: Handedness
    /// True when the video clearly showed the other arm swinging (mirrored
    /// selfie footage, or a left/right mix-up) and analysis followed it.
    let handWasCorrected: Bool

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
    /// The other wrist must travel at least this much more before we trust the
    /// footage over the profile's handedness.
    static let handSwapRatio: Double = 1.6

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
        let poseRequest = VNDetectHumanBodyPoseRequest()
        poseRequest.revision = VNDetectHumanBodyPoseRequestRevision1
        let stream = PoseStreamProcessor()

        var poses: [PoseFrame] = []
        var framesAnalyzed = 0
        var framesWithPlayer = 0
        var firstTimestamp: Double?
        var lastSampled = -Double.infinity
        var lastReported = -1.0
        let interval = 1.0 / poseFramesPerSecond

        progress(VideoAnalysisProgress(stage: .tracking, fraction: 0, repsFound: 0))

        // Pass 1: one tracked, smoothed pose stream for the filmed player.

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
            let candidates = autoreleasepool {
                PoseEngine.detectCandidates(in: pixelBuffer, orientation: orientation,
                                            time: time, using: poseRequest)
            }

            if let pose = stream.process(candidates: candidates, at: time) {
                if SetupCheckEvaluator.hasPlayer(pose) { framesWithPlayer += 1 }
                poses.append(pose)
            }

            // Tracking is the slow part; reserve the last 5% for scoring.
            let fraction = min(1, time / duration) * 0.95
            if fraction - lastReported >= 0.01 {
                lastReported = fraction
                progress(VideoAnalysisProgress(stage: .tracking, fraction: fraction, repsFound: 0))
            }
        }

        if reader.status == .failed { throw VideoAnalysisError.decodeFailed }
        guard framesAnalyzed > 0 else { throw VideoAnalysisError.decodeFailed }
        guard framesWithPlayer > 0 else { throw VideoAnalysisError.noPlayerFound }
        if Task.isCancelled { throw CancellationError() }

        // Pass 2: detect and score reps on the arm that is actually swinging.
        let hand = resolvePaddleHand(poses: poses, preferred: request.hand)
        let scored = detectAndScore(poses: poses, shot: request.shot, hand: hand,
                                    sessionID: request.sessionID, sessionStart: sessionStart)
        var reps = scored.map(\.rep)
        let repEndTimes = scored.map { (firstTimestamp ?? 0) + $0.endTime }

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
                                   framesAnalyzed: framesAnalyzed, framesWithPlayer: framesWithPlayer,
                                   analyzedHand: hand, handWasCorrected: hand != request.hand)
    }

    /// Runs a tracked pose stream through the live rep detector and per-rep
    /// pipeline. `endTime` is each rep's last frame on the pose clock.
    static func detectAndScore(poses: [PoseFrame], shot: ShotType, hand: Handedness,
                               sessionID: UUID, sessionStart: Date) -> [(rep: RepRecord, endTime: TimeInterval)] {
        let detector = RepDetector(hand: hand)
        var results: [(rep: RepRecord, endTime: TimeInterval)] = []
        for pose in poses {
            guard case .repCompleted(let window) = detector.ingest(pose) else { continue }
            let endTime = window.frames.last?.time ?? pose.time
            let outcome = RepPipeline.process(
                window: window, expected: shot, hand: hand,
                sessionID: sessionID, index: results.count + 1,
                timestamp: sessionStart.addingTimeInterval(endTime)
            )
            if let scored = outcome.scored { results.append((scored.rep, endTime)) }
        }
        return results
    }

    /// The profile's paddle hand, unless the footage clearly shows the other
    /// wrist doing the swinging. Mirrored selfie video and some filmed-from-
    /// behind clips swap Vision's left/right labels; scoring the idle arm would
    /// produce confident nonsense, so follow the arm that actually moves.
    static func resolvePaddleHand(poses: [PoseFrame], preferred: Handedness) -> Handedness {
        let preferredTravel = wristTravel(poses: poses, hand: preferred)
        let otherTravel = wristTravel(poses: poses, hand: preferred.opposite)
        // Needs real swinging (a few body-lengths of travel) to overrule the profile.
        guard otherTravel > 3 else { return preferred }
        return otherTravel >= preferredTravel * handSwapRatio ? preferred.opposite : preferred
    }

    /// Total wrist path in body scales, ignoring tracking dropouts.
    static func wristTravel(poses: [PoseFrame], hand: Handedness) -> Double {
        var total = 0.0
        for (previous, current) in zip(poses, poses.dropFirst()) {
            guard current.time - previous.time < 0.25,
                  let a = previous.wrist(for: hand), let b = current.wrist(for: hand) else { continue }
            let scale = max(0.02, current.bodyScale)
            total += PoseGeometry.distance(a, b) / scale
        }
        return total
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
