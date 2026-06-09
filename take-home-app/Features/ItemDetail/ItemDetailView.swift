//
//  ItemDetailView.swift
//

import SwiftUI

struct ItemDetailView: View {
    @State private var vm: ItemDetailViewModel
    private let fileStorage: FileStorage
    @Environment(\.scenePhase) private var scenePhase

    init(diContainer: DIContainer, itemID: String) {
        fileStorage = diContainer.fileStorage
        vm = .init(
            itemRepository: diContainer.itemRepository,
            processingEngine: diContainer.processingEngine,
            itemID: itemID
        )
    }

    var body: some View {
        StateContainer(vm.state) { detail in
            ItemDetailContent(detail: detail, fileStorage: fileStorage) { vm.process() }
        } empty: {
            ContentUnavailableView(
                "Item Unavailable",
                systemImage: "questionmark.folder",
                description: Text("This item is no longer available.")
            )
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { vm.start() }
        .task {
            while !Task.isCancelled {
                await vm.refreshEligibility()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.refreshEligibility() } }
        }
    }
}

private struct ItemDetailContent: View {
    let detail: ItemDetail
    let fileStorage: FileStorage
    let onProcess: () -> Void

    @State private var selectedPhotoID: DetailPhoto.ID?

    private var selectedPhoto: DetailPhoto? {
        detail.photos.first { $0.id == selectedPhotoID } ?? detail.photos.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mainImage
                if detail.photos.count > 1 {
                    ThumbnailStrip(
                        photos: detail.photos,
                        fileStorage: fileStorage,
                        selectedID: $selectedPhotoID
                    )
                }
                metadata
                ProcessActionBar(detail: detail, onProcess: onProcess)
                Divider()
                perPhotoSection
            }
            .padding()
        }
        .onAppear {
            if selectedPhotoID == nil { selectedPhotoID = detail.photos.first?.id }
        }
    }

    private var mainImage: some View {
        AsyncImageView(
            relativePaths: selectedPhoto?.displayImagePaths ?? [],
            fileStorage: fileStorage,
            targetPixelSize: 1200,
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .padding(12)
        .background(Color(.systemGray6), in: .rect(cornerRadius: 16))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.title)
                .font(.title2.bold())
            
            if let notes = detail.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            StatusBadge.forItem(
                processingStatus: detail.processingStatus,
                assetStatus: detail.assetStatus
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Label("Captured \(detail.createdAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                Label("Eligible \(detail.eligibleAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "hourglass")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var perPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Status")
                .font(.headline)
            ForEach(Array(detail.photos.enumerated()), id: \.element.id) { index, photo in
                DerivativeStatusRow(photo: photo, index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
