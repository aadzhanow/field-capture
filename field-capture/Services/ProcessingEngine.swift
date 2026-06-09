//
//  ProcessingEngine.swift
//

import Foundation

actor ProcessingEngine {
    private let itemRepository: ItemRepository
    private let processingRepository: ProcessingRepository
    private let fileStorage: FileStorage
    private let generator: DerivativeGenerator
    private let processingService: ProcessingService

    private let maxConcurrentGenerations = 3
    private var running: Set<String> = []
    private var submitting: Set<String> = []

    init(
        itemRepository: ItemRepository,
        processingRepository: ProcessingRepository,
        fileStorage: FileStorage,
        generator: DerivativeGenerator,
        processingService: ProcessingService
    ) {
        self.itemRepository = itemRepository
        self.processingRepository = processingRepository
        self.fileStorage = fileStorage
        self.generator = generator
        self.processingService = processingService
    }

    func enqueue(itemID: String) {
        guard running.insert(itemID).inserted else { return }
        Task { await self.run(itemID: itemID) }
    }

    private func run(itemID: String) async {
        defer { running.remove(itemID) }

        let work = (try? await itemRepository.pendingDerivativeWork(itemID: itemID)) ?? []
        guard !work.isEmpty else {
            try? await itemRepository.recomputeProcessingStatus(itemID: itemID)
            return
        }

        Log.processingInfo("Generating \(work.count) derivative(s) for item \(itemID)")

        let storage = fileStorage
        let generator = generator
        let repository = itemRepository

        await withTaskGroup(of: Void.self) { group in
            var next = 0
            let initial = min(maxConcurrentGenerations, work.count)
            while next < initial {
                let unit = work[next]
                next += 1
                group.addTask {
                    await Self.generateOne(unit, itemID: itemID, storage: storage, generator: generator, repository: repository)
                }
            }
            while await group.next() != nil {
                guard next < work.count else { continue }
                let unit = work[next]
                next += 1
                group.addTask {
                    await Self.generateOne(unit, itemID: itemID, storage: storage, generator: generator, repository: repository)
                }
            }
        }

        Log.processingInfo("Finished derivatives for item \(itemID)")
        try? await itemRepository.recomputeProcessingStatus(itemID: itemID)
    }

    private nonisolated static func generateOne(
        _ work: DerivativeWork,
        itemID: String,
        storage: FileStorage,
        generator: DerivativeGenerator,
        repository: ItemRepository
    ) async {
        do {
            let sourceData = try storage.read(work.originalPath)
            let derivativeData = try generator.generate(from: sourceData, kind: work.kind)
            let relativePath = storage.derivativeRelativePath(
                itemID: itemID, photoID: work.photoID, kind: work.kind
            )
            try storage.write(derivativeData, to: relativePath)
            try await repository.markDerivativeReady(
                id: work.derivativeID, path: relativePath, byteCount: derivativeData.count
            )
        } catch {
            Log.processingError("Derivative \(work.kind.rawValue) failed for item \(itemID)")
            try? await repository.markDerivativeFailed(id: work.derivativeID)
        }
    }

    // MARK: - Submit / Retry (manual)

    func submit(itemID: String) async {
        await runAttempt(itemID: itemID)
    }

    func retry(itemID: String) async {
        await runAttempt(itemID: itemID)
    }

    private func runAttempt(itemID: String) async {
        guard submitting.insert(itemID).inserted else { return }
        defer { submitting.remove(itemID) }

        guard let context = try? await processingRepository.submissionContext(itemID: itemID),
              Self.canSubmit(context)
        else {
            return
        }

        do {
            try await processingRepository.beginAttempt(itemID: itemID)
        } catch {
            return
        }

        Log.processingInfo("Submitting item \(itemID) for processing")

        let urls = context.processingPaths.map { fileStorage.url(for: $0) }
        do {
            let outcome = try await processingService.process(processingFiles: urls)
            Log.processingInfo("Item \(itemID) processing \(outcome == .success ? "succeeded" : "failed")")
            try? await processingRepository.finishAttempt(
                itemID: itemID,
                success: outcome == .success,
                lastError: outcome == .success ? nil : "Processing failed. Please retry."
            )
        } catch {
            Log.processingError("Item \(itemID) processing error: \(error.localizedDescription)")
            try? await processingRepository.finishAttempt(
                itemID: itemID,
                success: false,
                lastError: error.localizedDescription
            )
        }
    }

    private nonisolated static func canSubmit(_ context: SubmissionContext) -> Bool {
        guard context.processingStatus != .done, context.processingStatus != .processing else {
            return false
        }
        return context.isDerivativeComplete && context.isEligible
    }
}
