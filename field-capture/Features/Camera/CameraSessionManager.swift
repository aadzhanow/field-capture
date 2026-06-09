//
//  CameraSessionManager.swift
//

@preconcurrency import AVFoundation

/// Owns the `AVCaptureSession` and runs every session operation on its own serial
/// queue — deliberately not main-actor isolated, so its queue closures can touch
/// the session directly. Mutable state is only touched on `queue`.
nonisolated final class CaptureSessionManager: @unchecked Sendable {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.field-capture.camera.session")
    private var currentInput: AVCaptureDeviceInput?
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
            self.currentInput = input
            self.session.addOutput(self.photoOutput)
            self.session.commitConfiguration()
            completion(true)
        }
    }

    func switchCamera(to position: AVCaptureDevice.Position, completion: @escaping (Bool) -> Void) {
        queue.async {
            guard let current = self.currentInput,
                  let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: device)
            else {
                completion(false)
                return
            }
            self.session.beginConfiguration()
            self.session.removeInput(current)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
                self.session.commitConfiguration()
                completion(true)
            } else {
                self.session.addInput(current)
                self.session.commitConfiguration()
                completion(false)
            }
        }
    }

    func start() {
        queue.async { if !self.session.isRunning { self.session.startRunning() } }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func capture(flashMode: AVCaptureDevice.FlashMode, completion: @escaping (Data?) -> Void) {
        queue.async {
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            let id = settings.uniqueID
            let delegate = PhotoCaptureDelegate { [weak self] data in
                completion(data)
                self?.queue.async { self?.delegates[id] = nil }
            }
            self.delegates[id] = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
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
