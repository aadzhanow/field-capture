//
//  DebugViewModel.swift
//

import Foundation
import GRDB

@Observable
@MainActor
final class DebugViewModel {
    private let itemRepository: ItemRepository
    private(set) var items: [GalleryItem] = []

    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    init(itemRepository: ItemRepository) {
        self.itemRepository = itemRepository
    }

    func start() {
        guard cancellable == nil else { return }
        cancellable = itemRepository.observeGalleryItems(
            onChange: { [weak self] items in self?.items = items },
            onError: { _ in }
        )
    }

    /// Back-date the item past the 8h window so it becomes Ready to Process now.
    func makeEligible(_ id: String) {
        Task { try? await itemRepository.makeEligible(itemID: id) }
    }
}
