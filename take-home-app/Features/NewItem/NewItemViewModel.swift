//
//  NewItemViewModel.swift
//

import Foundation

@Observable
@MainActor
final class NewItemViewModel {
    private let itemRepository: ItemRepository

    var title: String = ""
    var notes: String = ""
    private(set) var pendingPhotos: [PendingPhoto] = []
    private(set) var state: SaveState = .editing(validation: nil)

    /// Flipped to `true` once the local save commits, so the host view can dismiss.
    private(set) var didSave = false

    init(itemRepository: ItemRepository) {
        self.itemRepository = itemRepository
    }

    // MARK: - Derived UI

    var canSave: Bool {
        !trimmedTitle.isEmpty && !pendingPhotos.isEmpty
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

    // MARK: - Photo intake

    /// Appends photos from raw image data (library import or camera capture),
    /// generating a cheap display thumbnail per photo off the main actor so the
    /// UI stays smooth while importing many photos at once.
    func addPhotos(_ datas: [Data]) async {
        for data in datas {
            let thumbnail = await Task.detached(priority: .userInitiated) {
                ImageDownsampling.thumbnail(from: data, maxPixelSize: 240)
            }.value
            guard let thumbnail else { continue }
            pendingPhotos.append(PendingPhoto(id: UUID().uuidString, data: data, thumbnail: thumbnail))
        }
        // Adding photos can resolve the "no photos" validation message.
        if case .editing = state { state = .editing(validation: nil) }
    }

    func addPhoto(_ data: Data) async {
        await addPhotos([data])
    }

    func removePhoto(_ id: PendingPhoto.ID) {
        pendingPhotos.removeAll { $0.id == id }
    }

    // MARK: - Save

    func save() async {
        // Validate first; surface validation distinct from a disk/DB save failure.
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
        // Capture order = array order; stamp it as sortOrder so the representative
        // photo (min sortOrder) is the first captured.
        let drafts = pendingPhotos.enumerated().map { index, photo in
            PhotoDraft(data: photo.data, sortOrder: index)
        }

        do {
            try await itemRepository.createItem(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                photos: drafts
            )
            state = .saved
            didSave = true
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
