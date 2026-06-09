//
//  DIContainer.swift
//

import Foundation

@MainActor
final class DIContainer {
    let appDatabase: AppDatabase
    let fileStorage: FileStorage
    let itemRepository: ItemRepository
    let derivativeGenerator: DerivativeGenerator
    let processingEngine: ProcessingEngine

    init() {
        do {
            let appDatabase = try AppDatabase.makeShared()
            let fileStorage = try DiskFileStorage()
            let itemRepository = ItemRepository(
                dbWriter: appDatabase.dbWriter,
                fileStorage: fileStorage
            )
            let derivativeGenerator = DefaultDerivativeGenerator()

            self.appDatabase = appDatabase
            self.fileStorage = fileStorage
            self.itemRepository = itemRepository
            self.derivativeGenerator = derivativeGenerator
            self.processingEngine = ProcessingEngine(
                itemRepository: itemRepository,
                fileStorage: fileStorage,
                generator: derivativeGenerator
            )
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }
}
