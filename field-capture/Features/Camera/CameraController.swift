//
//  CameraController.swift
//

@preconcurrency import AVFoundation
import SwiftUI

@Observable
@MainActor
final class CameraController {
    enum Status {
        case unknown, configuring, ready, denied, unavailable
    }

    private(set) var status: Status = .unknown
    private(set) var flashMode: AVCaptureDevice.FlashMode = .auto
    private(set) var cameraPosition: AVCaptureDevice.Position = .back
    private let manager = CaptureSessionManager()

    var session: AVCaptureSession { manager.session }

    var flashIconName: String {
        switch flashMode {
        case .on:   "bolt.fill"
        case .off:  "bolt.slash.fill"
        case .auto: "bolt.badge.automatic.fill"
        @unknown default: "bolt.slash.fill"
        }
    }

    func configureAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { status = .denied; return }
        case .denied, .restricted:
            status = .denied
            return
        @unknown default:
            status = .denied
            return
        }

        status = .configuring
        let configured = await withCheckedContinuation { continuation in
            manager.configure { continuation.resume(returning: $0) }
        }

        guard configured else { status = .unavailable; return }
        manager.start()
        status = .ready
    }

    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on:   flashMode = .off
        case .off:  flashMode = .auto
        @unknown default: flashMode = .auto
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back
        manager.switchCamera(to: newPosition) { [weak self] success in
            Task { @MainActor in
                if success { self?.cameraPosition = newPosition }
            }
        }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard status == .ready else { completion(nil); return }
        manager.capture(flashMode: flashMode) { data in
            Task { @MainActor in completion(data) }
        }
    }

    func stop() {
        manager.stop()
    }
}
