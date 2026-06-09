//
//  CameraView.swift
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// Full-screen AVFoundation capture. Stays open so the user can take **multiple
/// photos before saving** (§3/§4.3) — each shot calls `onCapture` and adds to the
/// pending grid; "Done" closes. Camera-less devices (e.g. the simulator) and
/// denied permission are handled explicitly instead of showing a black preview;
/// the PhotosPicker library path on the previous screen is the simulator fallback.
struct CameraView: View {
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var controller = CameraController()
    @State private var capturedCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch controller.status {
            case .unknown, .configuring:
                ProgressView().tint(.white)
            case .ready:
                cameraUI
            case .denied:
                message(
                    icon: "lock.slash",
                    title: "Camera Access Needed",
                    body: "Enable camera access in Settings to capture photos, or go back and add photos from your library.",
                    showSettings: true
                )
            case .unavailable:
                message(
                    icon: "camera.metering.unknown",
                    title: "Camera Unavailable",
                    body: "This device has no usable camera (the simulator has none). Go back and use “Library” to add photos.",
                    showSettings: false
                )
            }
        }
        .task { await controller.configureAndStart() }
        .onDisappear { controller.stop() }
    }

    // MARK: - Live camera

    private var cameraUI: some View {
        ZStack {
            CameraPreview(session: controller.session).ignoresSafeArea()

            VStack {
                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    if capturedCount > 0 {
                        Text("^[\(capturedCount) photo](inflect: true)")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: .capsule)
                    }
                }
                .foregroundStyle(.white)
                .padding()

                Spacer()

                ZStack {
                    Button(action: capture) {
                        Circle()
                            .fill(.white)
                            .frame(width: 68, height: 68)
                            .overlay {
                                Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                            }
                    }

                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .disabled(capturedCount == 0)
                            .padding(.trailing)
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func capture() {
        controller.capturePhoto { data in
            guard let data else { return }
            capturedCount += 1
            onCapture(data)
        }
    }

    // MARK: - Unavailable / denied state

    private func message(icon: String, title: String, body: String, showSettings: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
            Text(title).font(.title3.weight(.semibold))
            Text(body)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
                Button("Back") { dismiss() }
                    .buttonStyle(.borderedProminent)
                if showSettings {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(40)
    }
}

// MARK: - Capture session controller

/// Main-actor-isolated, observable status holder for the camera UI. All actual
/// AVFoundation work is delegated to `CaptureSessionManager`, which lives off the
/// main actor — so the session is never touched across an isolation boundary.
@Observable
@MainActor
final class CameraController {
    enum Status {
        case unknown, configuring, ready, denied, unavailable
    }

    private(set) var status: Status = .unknown
    private let manager = CaptureSessionManager()

    var session: AVCaptureSession { manager.session }

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

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        guard status == .ready else { completion(nil); return }
        manager.capture { data in
            Task { @MainActor in completion(data) }
        }
    }

    func stop() {
        manager.stop()
    }
}

/// Owns the `AVCaptureSession` and runs every session operation on its own serial
/// queue. Deliberately **not** main-actor isolated, so its queue closures can
/// touch the session directly without crossing an isolation boundary. Mutable
/// state (`delegates`) is only ever touched on `queue`, hence `@unchecked Sendable`.
private final class CaptureSessionManager: @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.take-home-app.camera.session")
    /// Capture delegates are retained until their photo finishes — the photo
    /// output does not retain its delegate.
    private var delegates: [Int64: PhotoCaptureDelegate] = [:]

    func configure(completion: @escaping (Bool) -> Void) {
        queue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
            guard let camera,
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input),
                  self.session.canAddOutput(self.photoOutput)
            else {
                self.session.commitConfiguration()
                completion(false)
                return
            }
            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            self.session.commitConfiguration()
            completion(true)
        }
    }

    func start() {
        queue.async { if !self.session.isRunning { self.session.startRunning() } }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func capture(_ completion: @escaping (Data?) -> Void) {
        let settings = AVCapturePhotoSettings()
        let id = settings.uniqueID
        let delegate = PhotoCaptureDelegate { [weak self] data in
            completion(data)
            self?.queue.async { self?.delegates[id] = nil }
        }
        queue.async {
            self.delegates[id] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        completion(error == nil ? photo.fileDataRepresentation() : nil)
    }
}

// MARK: - Preview layer

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
