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
                self?.state = detail.map { .loaded($0) } ?? .empty
            },
            onError: { [weak self] error in self?.state = .error(error.localizedDescription) }
        )
    }

    func process() {
        Task { await processingEngine.submit(itemID: itemID) }
    }

    func refreshEligibility() async {
        try? await itemRepository.recomputeProcessingStatus(itemID: itemID)
    }
}
