//
//  ItemDetailViewModel.swift
//

import Foundation
import GRDB

@Observable
@MainActor
final class ItemDetailViewModel {
    private let itemRepository: ItemRepository
    private let itemID: String
    private(set) var state: ViewState<ItemDetail> = .loading

    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    init(itemRepository: ItemRepository, itemID: String) {
        self.itemRepository = itemRepository
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
}
