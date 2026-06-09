//
//  MockProcessingService.swift
//

import Foundation

nonisolated final class MockProcessingService: ProcessingService {
    private let debug: DebugSettings
    private let latency: Duration

    init(debug: DebugSettings, latency: Duration = .seconds(2)) {
        self.debug = debug
        self.latency = latency
    }

    func process(processingFiles: [URL]) async throws -> ProcessingOutcome {
        guard !processingFiles.isEmpty,
              processingFiles.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) })
        else {
            throw ProcessingError.invalidPayload
        }

        try? await Task.sleep(for: latency)

        if await debug.simulateOffline { throw ProcessingError.offline }
        if await debug.consumeForcedFailure() { throw ProcessingError.simulated }

        return Bool.random() ? .success : .failure
    }
}
