//
//  DIContainer.swift
//

import Foundation

@MainActor
final class DIContainer {
    let appDatabase: AppDatabase
    let fileStorage: FileStorage
    let itemRepository: ItemRepository
    let processingRepository: ProcessingRepository
    let derivativeGenerator: DerivativeGenerator
    let debugSettings: DebugSettings
    let processingService: ProcessingService
    let processingEngine: ProcessingEngine
    let recoveryService: RecoveryService

    init() {
        do {
            let appDatabase = try AppDatabase.makeShared()
            let fileStorage = try DiskFileStorage()
            let itemRepository = ItemRepository(
                dbWriter: appDatabase.dbWriter,
                fileStorage: fileStorage
            )
            let processingRepository = ProcessingRepository(dbWriter: appDatabase.dbWriter)
            let derivativeGenerator = DefaultDerivativeGenerator()
            let debugSettings = DebugSettings()
            let processingService = MockProcessingService(debug: debugSettings)

            self.appDatabase = appDatabase
            self.fileStorage = fileStorage
            self.itemRepository = itemRepository
            self.processingRepository = processingRepository
            self.derivativeGenerator = derivativeGenerator
            self.debugSettings = debugSettings
            self.processingService = processingService
            let processingEngine = ProcessingEngine(
                itemRepository: itemRepository,
                processingRepository: processingRepository,
                fileStorage: fileStorage,
                generator: derivativeGenerator,
                processingService: processingService
            )
            self.processingEngine = processingEngine
            self.recoveryService = RecoveryService(
                itemRepository: itemRepository,
                processingRepository: processingRepository,
                fileStorage: fileStorage,
                processingEngine: processingEngine
            )
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }
}
