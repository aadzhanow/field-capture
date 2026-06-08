//
//  DIContainer.swift
//

import Foundation

@MainActor
final class DIContainer {
    let appDatabase: AppDatabase
    let itemRepository: ItemRepository

    init() {
        do {
            let appDatabase = try AppDatabase.makeShared()
            self.appDatabase = appDatabase
            self.itemRepository = ItemRepository(dbWriter: appDatabase.dbWriter)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }
}
