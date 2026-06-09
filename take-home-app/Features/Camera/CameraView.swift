//
//  CameraView.swift
//

import SwiftUI
import UIKit

struct CameraView: View {
    let onCapture: (String, Data) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var controller = CameraController()
    @State private var capturedPhotos: [SessionPhoto] = []
    @State private var showingPreviews = false

    private var capturedCount: Int { capturedPhotos.count }
    private var lastThumbnail: UIImage? { capturedPhotos.last?.thumbnail }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch controller.status {
                case .unknown, .configuring:
                    ProgressView().tint(.white)
                case .ready:
                    cameraUI
                case .denied:
                    CameraUnavailableView(
                        icon: "lock.slash",
                        title: "Camera Access Needed",
                        message: "Enable camera access in Settings to capture photos, or go back and add photos from your library.",
                        showSettings: true
                    )
                case .unavailable:
                    CameraUnavailableView(
                        icon: "camera.metering.unknown",
                        title: "Camera Unavailable",
                        message: "This device has no usable camera (the simulator has none). Go back and use “Library” to add photos.",
                        showSettings: false
                    )
                }
            }
            .tint(.white)
            .toolbar { cameraToolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task { await controller.configureAndStart() }
        .onDisappear { controller.stop() }
        .sheet(isPresented: $showingPreviews) {
            CapturedPreviewSheet(photos: capturedPhotos) { deleteCaptured($0) }
        }
    }

    @ToolbarContentBuilder
    private var cameraToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
            }
        }
        if controller.status == .ready {
            ToolbarItem(placement: .topBarTrailing) {
                Button { controller.toggleFlash() } label: {
                    Image(systemName: controller.flashIconName)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { controller.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                }
            }
        }
    }

    private var cameraUI: some View {
        ZStack {
            CameraPreview(session: controller.session).ignoresSafeArea()

            VStack {
                Spacer()
                CameraControlsBar(
                    capturedCount: capturedCount,
                    lastThumbnail: lastThumbnail,
                    onShutter: capture,
                    onThumbnailTap: { showingPreviews = true },
                    onDone: { dismiss() }
                )
            }
        }
    }

    private func capture() {
        let id = UUID().uuidString
        controller.capturePhoto { data in
            guard let data else { return }
            onCapture(id, data)
            capturedPhotos.append(SessionPhoto(id: id, data: data, thumbnail: nil))
            Task {
                let thumbnail = await Task.detached {
                    ImageDownsampling.thumbnail(from: data, maxPixelSize: 200)
                }.value
                if let index = capturedPhotos.firstIndex(where: { $0.id == id }) {
                    capturedPhotos[index].thumbnail = thumbnail
                }
            }
        }
    }

    private func deleteCaptured(_ id: String) {
        capturedPhotos.removeAll { $0.id == id }
        onDelete(id)
        if capturedPhotos.isEmpty { showingPreviews = false }
    }
}
