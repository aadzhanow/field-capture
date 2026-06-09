//
//  MockProcessingService.swift
//

import Foundation

/// The required mock backend — no real network call. It randomly succeeds or
/// fails (so the failure path is real, not invisible), with debug-forced offline
/// and failure outcomes for deterministic testing. A short simulated latency
/// makes the "Processing" state observable in the UI.
nonisolated final class MockProcessingService: ProcessingService {
    private let debug: DebugSettings
    private let latency: Duration

    init(debug: DebugSettings, latency: Duration = .seconds(2)) {
        self.debug = debug
        self.latency = latency
    }

    func process(processingFiles: [URL]) async throws -> ProcessingOutcome {
        try? await Task.sleep(for: latency)

        // Debug-forced outcomes win over the random result.
        if await debug.simulateOffline { throw ProcessingError.offline }
        if await debug.consumeForcedFailure() { throw ProcessingError.simulated }

        return Bool.random() ? .success : .failure
    }
}
