//
//  ProcessingEngine.swift
//

import Foundation

/// The single, long-lived owner of the post-save async lifecycle. An `actor`,
/// owned by `DIContainer` (never by a ViewModel), so a 25-photo job is never
/// cancelled by a screen being dismissed. The save path and (later)
/// `RecoveryService` are its callers — one entry point, two triggers.
///
/// In Phase 3 it owns derivative generation: for an enqueued item it generates
/// every not-yet-ready derivative under the ≤700KB cap, persists each row as it
/// lands, then recomputes the item's processing status. Submission/retry (P5)
/// will add `submit`/`retry` here.
actor ProcessingEngine {
    private let itemRepository: ItemRepository
    private let processingRepository: ProcessingRepository
    private let fileStorage: FileStorage
    private let generator: DerivativeGenerator
    private let processingService: ProcessingService

    /// Bounds parallel image decode/encode so a 25-photo item doesn't spawn 125
    /// concurrent large-image operations and stutter/OOM (§4.3/§11).
    private let maxConcurrentGenerations = 3

    /// Items currently generating, so a duplicate `enqueue` is a no-op.
    private var running: Set<String> = []
    /// Items with a processing attempt in flight, so a double-tap is a no-op.
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

    /// Fire-and-forget: schedules generation for an item and returns immediately,
    /// so the gallery card shows the moment the save commits. Idempotent — a
    /// second enqueue while one is in flight is ignored, and a re-run only
    /// regenerates rows still `pending`/`failed` (so recovery reuses this path).
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

        // Capture Sendable dependencies into locals so the bounded child tasks run
        // off-actor (and off the main actor) without touching the engine.
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
            // Keep the in-flight count at the cap: each completion pulls the next.
            while await group.next() != nil {
                guard next < work.count else { continue }
                let unit = work[next]
                next += 1
                group.addTask {
                    await Self.generateOne(unit, itemID: itemID, storage: storage, generator: generator, repository: repository)
                }
            }
        }

        try? await itemRepository.recomputeProcessingStatus(itemID: itemID)
    }

    /// `nonisolated static`: runs on the cooperative pool, never on the engine
    /// actor or the main actor. Reads the original, generates the derivative
    /// (CPU-heavy, off-main), writes it atomically, then flips the row to `ready`
    /// last — so a crash mid-generation leaves the row `pending`, never a partial
    /// file marked `ready`.
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
            // Over-limit or undecodable → `failed`, never an over-limit `ready`.
            // That surfaces as "Assets Failed" and blocks readiness.
            try? await repository.markDerivativeFailed(id: work.derivativeID)
        }
    }

    // MARK: - Submit / Retry (manual)

    /// Manual submission from the Process button. Re-checks both readiness gates
    /// and the `done`/`processing` guard before starting.
    func submit(itemID: String) async {
        await runAttempt(itemID: itemID)
    }

    /// Retry is the same path — the Process button doubles as Retry when failed.
    func retry(itemID: String) async {
        await runAttempt(itemID: itemID)
    }

    private func runAttempt(itemID: String) async {
        guard submitting.insert(itemID).inserted else { return }
        defer { submitting.remove(itemID) }

        // Re-check both gates + the done/processing guard against fresh DB state.
        guard let context = try? await processingRepository.submissionContext(itemID: itemID),
              Self.canSubmit(context)
        else {
            return
        }

        // Persist the start BEFORE the await, so an attempt interrupted by a
        // crash is recoverable (reset to `failed` in P6), never lost.
        do {
            try await processingRepository.beginAttempt(itemID: itemID)
        } catch {
            return
        }

        let urls = context.processingPaths.map { fileStorage.url(for: $0) }
        do {
            let outcome = try await processingService.process(processingFiles: urls)
            try? await processingRepository.finishAttempt(
                itemID: itemID,
                success: outcome == .success,
                lastError: outcome == .success ? nil : "Processing failed. Please retry."
            )
        } catch {
            try? await processingRepository.finishAttempt(
                itemID: itemID,
                success: false,
                lastError: error.localizedDescription
            )
        }
    }

    /// Both readiness gates plus the single guard that makes `done` terminal and
    /// blocks a second attempt while one is in progress. All callers route here.
    private nonisolated static func canSubmit(_ context: SubmissionContext) -> Bool {
        guard context.processingStatus != .done, context.processingStatus != .processing else {
            return false
        }
        return context.isDerivativeComplete && context.isEligible
    }
}
