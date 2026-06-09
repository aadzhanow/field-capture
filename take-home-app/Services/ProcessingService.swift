//
//  ProcessingService.swift
//

import Foundation

enum ProcessingOutcome: Sendable {
    case success
    case failure
}

enum ProcessingError: LocalizedError, Sendable {
    case offline
    case simulated

    var errorDescription: String? {
        switch self {
        case .offline:   "No connection. Processing is unavailable offline."
        case .simulated: "Forced failure (debug)."
        }
    }
}

/// The backend seam (no real network). It only *yields an outcome* for the
/// supplied processing-derivative files — it does **not** touch the DB.
/// Persistence (attempts, submittedAt, completedAt, lastError, status) is owned
/// by `ProcessingEngine`, which keeps this mock trivial and the persistence in
/// one place. `nonisolated` so it runs off the main actor.
protocol ProcessingService: Sendable {
    nonisolated func process(processingFiles: [URL]) async throws -> ProcessingOutcome
}
