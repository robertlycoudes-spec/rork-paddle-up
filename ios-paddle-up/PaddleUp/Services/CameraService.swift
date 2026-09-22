//
//  CameraService.swift
//  PaddleUp
//
//  Continuous AVCaptureSession for practice. The player never taps record —
//  the session runs the whole time and the rep detector decides what matters.
//

import AVFoundation
import Combine
import SwiftUI

nonisolated enum CameraAuthorizationState: Equatable, Sendable {
    case undetermined
    case authorized
    case denied
    case noDeviceFound
}

@MainActor
@Observable
final class CameraService: NSObject {
    private(set) var authorization: CameraAuthorizationState = .undetermined
    private(set) var isRunning = false
    /// Nil until the session has produced at least one frame.
    private(set) var isReceivingFrames = false

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.paddleup.camera")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false

    /// Set by the practice engine to receive frames.
    nonisolated(unsafe) var sampleHandler: (@Sendable (CMSampleBuffer) -> Void)?

    override init() {
        super.init()
    }

    func requestAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        default:
            authorization = .denied
        }
    }

    func start() async {
        await requestAccess()
        guard authorization == .authorized else { return }

        if !isConfigured {
            let configured = await configure()
            guard configured else {
                authorization = .noDeviceFound
                return
            }
            isConfigured = true
        }

        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
        isRunning = true
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
        isRunning = false
        isReceivingFrames = false
    }

    /// Discovery deliberately lists the built-in camera first so physical
    /// devices prefer it; the cloud simulator has none and falls through to the
    /// injected external camera.
    private nonisolated static func bestCamera() -> AVCaptureDevice? {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(iOS 17.0, *) { types.append(.external) }
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types,
                                                         mediaType: .video,
                                                         position: .unspecified)
        return discovery.devices.first { $0.position == .back } ?? discovery.devices.first
    }

    private func configure() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(returning: false); return }
                guard let device = Self.bestCamera(),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    continuation.resume(returning: false)
                    return
                }

                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720

                if self.session.canAddInput(input) { self.session.addInput(input) }

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "app.paddleup.frames"))
                if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }

                if let connection = self.videoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    }
                }

                self.session.commitConfiguration()
                continuation.resume(returning: true)
            }
        }
    }

    fileprivate func markReceivingFrames() {
        if !isReceivingFrames { isReceivingFrames = true }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        sampleHandler?(sampleBuffer)
        Task { @MainActor [weak self] in self?.markReceivingFrames() }
    }
}

/// Live camera preview layer.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {}

    final class PreviewContainer: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
