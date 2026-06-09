//
//  RecoveryService.swift
//

import Foundation

nonisolated final class RecoveryService: Sendable {
    private let itemRepository: ItemRepository
    private let processingRepository: ProcessingRepository
    private let fileStorage: FileStorage
    private let processingEngine: ProcessingEngine

    init(
        itemRepository: ItemRepository,
        processingRepository: ProcessingRepository,
        fileStorage: FileStorage,
        processingEngine: ProcessingEngine
    ) {
        self.itemRepository = itemRepository
        self.processingRepository = processingRepository
        self.fileStorage = fileStorage
        self.processingEngine = processingEngine
    }

    func recover() async {
        try? await processingRepository.resetStuckJobs()
        await reconcileMissingDerivativeFiles()
        await sweepOrphanFiles()
        let itemIDs = (try? await itemRepository.itemIDsWithUnfinishedDerivatives()) ?? []
        for itemID in itemIDs {
            await processingEngine.enqueue(itemID: itemID)
        }
    }

    private func reconcileMissingDerivativeFiles() async {
        guard let refs = try? await itemRepository.readyDerivativeFileRefs() else { return }
        let missingIDs = refs.filter { !fileStorage.exists($0.path) }.map(\.id)
        if !missingIDs.isEmpty {
            try? await itemRepository.markDerivativesPending(ids: missingIDs)
        }
    }

    private func sweepOrphanFiles() async {
        guard let referenced = try? await itemRepository.allReferencedFilePaths() else { return }
        let onDisk = (try? fileStorage.allStoredRelativePaths()) ?? []
        for path in onDisk where !referenced.contains(path) {
            try? fileStorage.delete(path)
        }
    }
}
