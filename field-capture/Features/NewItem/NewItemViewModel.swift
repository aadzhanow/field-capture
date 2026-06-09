//
//  NewItemViewModel.swift
//

import Foundation

@Observable
@MainActor
final class NewItemViewModel {
    private let itemRepository: ItemRepository
    private let processingEngine: ProcessingEngine

    var title: String = ""
    var notes: String = ""
    private(set) var pendingPhotos: [PendingPhoto] = []
    private(set) var state: SaveState = .editing(validation: nil)

    private(set) var didSave = false

    init(itemRepository: ItemRepository, processingEngine: ProcessingEngine) {
        self.itemRepository = itemRepository
        self.processingEngine = processingEngine
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty && !pendingPhotos.isEmpty
    }

    var canAddMorePhotos: Bool {
        pendingPhotos.count < Constants.maxPhotosPerItem
    }

    var remainingPhotoSlots: Int {
        max(0, Constants.maxPhotosPerItem - pendingPhotos.count)
    }

    var isSaving: Bool {
        if case .saving = state { true } else { false }
    }

    var validationError: ItemValidationError? {
        if case .editing(let validation) = state { validation } else { nil }
    }

    var saveErrorMessage: String? {
        if case .failed(let message) = state { message } else { nil }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func addPhotos(_ datas: [Data]) async {
        for data in datas {
            guard canAddMorePhotos else { break }
            let thumbnail = await Task.detached(priority: .userInitiated) {
                ImageDownsampling.thumbnail(from: data, maxPixelSize: 240)
            }.value
            guard let thumbnail, canAddMorePhotos else { continue }
            pendingPhotos.append(PendingPhoto(id: UUID().uuidString, data: data, thumbnail: thumbnail))
        }
        if case .editing = state { state = .editing(validation: nil) }
    }

    func addPhoto(id: String, data: Data) async {
        guard canAddMorePhotos else { return }
        let thumbnail = await Task.detached(priority: .userInitiated) {
            ImageDownsampling.thumbnail(from: data, maxPixelSize: 240)
        }.value
        guard let thumbnail, canAddMorePhotos else { return }
        pendingPhotos.append(PendingPhoto(id: id, data: data, thumbnail: thumbnail))
        if case .editing = state { state = .editing(validation: nil) }
    }

    func removePhoto(_ id: PendingPhoto.ID) {
        pendingPhotos.removeAll { $0.id == id }
    }

    func save() async {
        if trimmedTitle.isEmpty {
            state = .editing(validation: .titleEmpty)
            return
        }
        if pendingPhotos.isEmpty {
            state = .editing(validation: .noPhotos)
            return
        }

        state = .saving
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let drafts = pendingPhotos.enumerated().map { index, photo in
            PhotoDraft(data: photo.data, sortOrder: index)
        }

        do {
            let itemID = try await itemRepository.createItem(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                photos: drafts
            )
            await processingEngine.enqueue(itemID: itemID)
            state = .saved
            didSave = true
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
