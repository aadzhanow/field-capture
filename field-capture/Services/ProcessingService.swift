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
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .offline:        "No connection. Processing is unavailable offline."
        case .simulated:      "Forced failure (debug)."
        case .invalidPayload: "No processing images were available to submit."
        }
    }
}

protocol ProcessingService: Sendable {
    nonisolated func process(processingFiles: [URL]) async throws -> ProcessingOutcome
}
