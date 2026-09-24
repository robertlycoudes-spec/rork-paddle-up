//
//  ClipRecorder.swift
//  PaddleUp
//
//  Rolling-buffer clip capture. Full practice sessions are never written to
//  disk: frames live in a short in-memory ring buffer, and only the ~3 seconds
//  around a detected rep are ever encoded to a file.
//
//  Benefits: cheaper, faster, more private, far less storage.
//

import AVFoundation
import CoreImage
import Foundation
import OSLog
import UIKit

/// Encodes short clips from buffered frames around a detected rep.
nonisolated final class ClipRecorder: @unchecked Sendable {
    private struct BufferedFrame {
        let image: CGImage
        let time: CFTimeInterval
    }

    private let logger = Logger(subsystem: "app.paddleup", category: "clips")
    private let bufferQueue = DispatchQueue(label: "app.paddleup.clipbuffer")
    private let context = CIContext()

    /// Seconds of video retained in memory at any moment.
    private let bufferSeconds: CFTimeInterval = 4.5
    /// Frames per second retained (downsampled from the camera).
    private let captureFPS: Int = 12
    private let clipWidth: CGFloat = 480

    private var buffer: [BufferedFrame] = []
    private var lastCaptureTime: CFTimeInterval = 0
    private let outputDirectory: URL

    /// Toggled off when the player disables clip saving.
    var isEnabled: Bool = true

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    func reset() {
        bufferQueue.async { [weak self] in
            self?.buffer.removeAll()
        }
    }

    /// Feed a camera frame into the rolling buffer. Old frames fall off the back.
    func ingest(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation, now: CFTimeInterval) {
        guard isEnabled else { return }
        guard now - lastCaptureTime >= 1.0 / Double(captureFPS) else { return }
        lastCaptureTime = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Same orientation the pose engine uses, so clips are upright.
        if orientation != .up { ciImage = ciImage.oriented(orientation) }
        ciImage = ciImage.transformed(by: CGAffineTransform(translationX: -ciImage.extent.minX,
                                                            y: -ciImage.extent.minY))
        let scale = clipWidth / max(1, ciImage.extent.width)
        if scale < 1 {
            ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        bufferQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(BufferedFrame(image: cgImage, time: now))
            let cutoff = now - self.bufferSeconds
            self.buffer.removeAll { $0.time < cutoff }
        }
    }

    /// Write the frames spanning a rep to an MP4 and return its filename.
    /// Everything outside the window is discarded.
    func saveClip(around endTime: CFTimeInterval, duration: CFTimeInterval = 3.0) async -> String? {
        guard isEnabled else { return nil }

        let frames: [BufferedFrame] = await withCheckedContinuation { continuation in
            bufferQueue.async { [weak self] in
                guard let self else { continuation.resume(returning: []); return }
                let start = endTime - duration
                continuation.resume(returning: self.buffer.filter { $0.time >= start && $0.time <= endTime + 0.4 })
            }
        }

        guard frames.count >= 4, let first = frames.first else { return nil }

        let filename = "rep-\(UUID().uuidString).mp4"
        let url = outputDirectory.appendingPathComponent(filename)
        let size = CGSize(width: first.image.width, height: first.image.height)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_400_000]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(captureFPS))
        for (index, frame) in frames.enumerated() {
            guard let pool = adaptor.pixelBufferPool,
                  let pixelBuffer = makePixelBuffer(from: frame.image, pool: pool, size: size) else { continue }
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            var attempts = 0
            while !input.isReadyForMoreMediaData && attempts < 100 {
                try? await Task.sleep(for: .milliseconds(8))
                attempts += 1
            }
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            logger.error("Clip encode failed.")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return filename
    }

    private func makePixelBuffer(from image: CGImage, pool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
