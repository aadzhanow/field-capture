//
//  DIContainer.swift
//

import Foundation

@MainActor
final class DIContainer {
    let appDatabase: AppDatabase
    let fileStorage: FileStorage
    let itemRepository: ItemRepository

    init() {
        do {
            let appDatabase = try AppDatabase.makeShared()
            let fileStorage = try DiskFileStorage()
            self.appDatabase = appDatabase
            self.fileStorage = fileStorage
            self.itemRepository = ItemRepository(
                dbWriter: appDatabase.dbWriter,
                fileStorage: fileStorage
            )
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }
}
