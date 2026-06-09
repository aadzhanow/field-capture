//
//  ItemListViewModel.swift
//

import Foundation
import GRDB

@Observable
@MainActor
final class ItemListViewModel {
    private let itemRepository: ItemRepository
    private(set) var state: ViewState<[ItemListSection]> = .loading

    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    init(itemRepository: ItemRepository) {
        self.itemRepository = itemRepository
    }

    func start() {
        guard cancellable == nil else { return }
        cancellable = itemRepository.observeItemListItems(
            onChange: { [weak self] items in self?.apply(items) },
            onError: { [weak self] error in self?.state = .error(error.localizedDescription) }
        )
    }

    private func apply(_ items: [ItemListItem]) {
        state = items.isEmpty ? .empty : .loaded(ItemListSection.group(items))
    }

    func refreshEligibility() async {
        try? await itemRepository.promoteEligibleItems()
    }
}
