//
//  GalleryViewModel.swift
//

import Foundation
import GRDB

@Observable
@MainActor
final class GalleryViewModel {
    private let itemRepository: ItemRepository
    private(set) var state: ViewState<[GallerySection]> = .loading

    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    init(itemRepository: ItemRepository) {
        self.itemRepository = itemRepository
    }

    func start() {
        guard cancellable == nil else { return }
        cancellable = itemRepository.observeGalleryItems(
            onChange: { [weak self] items in self?.apply(items) },
            onError: { [weak self] error in self?.state = .error(error.localizedDescription) }
        )
    }

    private func apply(_ items: [GalleryItem]) {
        state = items.isEmpty ? .empty : .loaded(GallerySection.group(items))
    }

    /// Promote complete, now-eligible items to Ready. ValueObservation fires on
    /// DB writes, not the wall clock, so the view drives this on a timer / when
    /// the app becomes active, and the badges flip on their own.
    func refreshEligibility() async {
        try? await itemRepository.promoteEligibleItems()
    }

    #if DEBUG
    func debugInsertItem() async {
        do {
            try await itemRepository.insertDebugItem()
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    #endif
}
