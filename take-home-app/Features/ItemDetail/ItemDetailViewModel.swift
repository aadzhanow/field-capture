//
//  ItemDetailViewModel.swift
//

import Foundation
import GRDB

@Observable
@MainActor
final class ItemDetailViewModel {
    private let itemRepository: ItemRepository
    private let processingEngine: ProcessingEngine
    private let itemID: String
    private(set) var state: ViewState<ItemDetail> = .loading

    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    init(itemRepository: ItemRepository, processingEngine: ProcessingEngine, itemID: String) {
        self.itemRepository = itemRepository
        self.processingEngine = processingEngine
        self.itemID = itemID
    }

    func start() {
        guard cancellable == nil else { return }
        cancellable = itemRepository.observeItemDetail(
            itemID: itemID,
            onChange: { [weak self] detail in
                // A nil detail means the item no longer exists (e.g. deleted).
                self?.state = detail.map { .loaded($0) } ?? .empty
            },
            onError: { [weak self] error in self?.state = .error(error.localizedDescription) }
        )
    }

    /// Manual Process / Retry — the engine re-checks both gates and the
    /// done/processing guard, so this is safe to call unconditionally.
    func process() {
        Task { await processingEngine.submit(itemID: itemID) }
    }

    /// Re-evaluate the 8h window (ValueObservation fires on DB writes, not the
    /// clock), so a complete item flips to Ready on its own while open.
    func refreshEligibility() async {
        try? await itemRepository.recomputeProcessingStatus(itemID: itemID)
    }
}
