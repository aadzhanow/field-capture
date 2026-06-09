//
//  RecoveryService.swift
//

import Foundation

/// On launch, reconcile the persisted state left by an interrupted run and
/// re-drive whatever is unfinished — **without ever touching `done`**.
///
/// It is a thin reconciler by design: the hard part was front-loaded into the
/// persisted spine (pre-seeded derivative matrix, atomic write-then-flip,
/// persist-before-await for jobs), so recovery only has to find the unfinished
/// rows and resume them through the *same* `enqueue` entry point the save path
/// uses. Running it twice is safe (idempotent).
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
        // 1. Rescue jobs interrupted mid-processing → failed (retryable). Never
        //    touches `done`.
        try? await processingRepository.resetStuckJobs()

        // 2a. A `ready` derivative whose file vanished → back to `pending`.
        await reconcileMissingDerivativeFiles()

        // 2b. Sweep files with no DB reference: originals staged by a save that
        //     never committed, or derivative files written just before the
        //     status flip was interrupted. (Runs at cold launch, before any
        //     user-initiated save could commit, so it can't race a live save.)
        await sweepOrphanFiles()

        // 3. Resume generation for every item with unfinished derivatives — the
        //    same `enqueue` the save path calls (one code path, two callers).
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
