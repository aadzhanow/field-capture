//
//  ProcessingService.swift
//

import Foundation

nonisolated enum ProcessingOutcome: Sendable {
    case success
    case failure
}

nonisolated enum ProcessingError: LocalizedError, Sendable {
    case offline
    case simulated

    var errorDescription: String? {
        switch self {
        case .offline:   "No connection. Processing is unavailable offline."
        case .simulated: "Forced failure (debug)."
        }
    }
}

protocol ProcessingService: Sendable {
    nonisolated func process(processingFiles: [URL]) async throws -> ProcessingOutcome
}
