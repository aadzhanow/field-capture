//
//  ProcessingRepository.swift
//

import Foundation
import GRDB

nonisolated struct SubmissionContext: Sendable {
    let processingStatus: ProcessingStatus
    let isDerivativeComplete: Bool
    let isEligible: Bool
    let processingPaths: [String]
}

nonisolated final class ProcessingRepository: Sendable {
    private let dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func submissionContext(itemID: String) async throws -> SubmissionContext? {
        try await dbWriter.read { db in
            guard let item = try Item.fetchOne(db, key: itemID) else { return nil }

            let counts = try SubmissionCounts.fetchOne(db, sql: """
                SELECT
                  (SELECT COUNT(*) FROM photo WHERE itemId = :id) AS photoCount,
                  (SELECT COUNT(*) FROM derivative d JOIN photo p ON p.id = d.photoId
                     WHERE p.itemId = :id) AS total,
                  (SELECT COUNT(*) FROM derivative d JOIN photo p ON p.id = d.photoId
                     WHERE p.itemId = :id AND d.statusRaw = 'ready') AS ready
                """, arguments: ["id": itemID]) ?? SubmissionCounts(photoCount: 0, total: 0, ready: 0)

            let expected = counts.photoCount * DerivativeKind.allCases.count
            let complete = counts.photoCount > 0 && counts.total == expected && counts.ready == expected

            let paths = try String.fetchAll(db, sql: """
                SELECT d.path FROM derivative d
                  JOIN photo p ON p.id = d.photoId
                 WHERE p.itemId = ? AND d.kind = ? AND d.statusRaw = 'ready' AND d.path IS NOT NULL
                 ORDER BY p.sortOrder ASC
                """, arguments: [itemID, DerivativeKind.processing.rawValue])

            let eligible = Date().timeIntervalSince1970 >= item.createdAt + Constants.eligibilityWindow

            return SubmissionContext(
                processingStatus: ProcessingStatus(rawValue: item.processingStatusRaw) ?? .notReady,
                isDerivativeComplete: complete,
                isEligible: eligible,
                processingPaths: paths
            )
        }
    }

    // persist before the network await so a crash mid-attempt leaves a recoverable job
    func beginAttempt(itemID: String) async throws {
        try await dbWriter.write { db in
            let now = Date().timeIntervalSince1970
            if var job = try ProcessingJob
                .filter(ProcessingJob.Columns.itemId == itemID)
                .fetchOne(db) {
                job.statusRaw = ProcessingStatus.processing.rawValue
                job.attemptCount += 1
                job.submittedAt = now
                job.completedAt = nil
                job.lastError = nil
                try job.update(db)
            } else {
                try ProcessingJob(
                    id: UUID().uuidString,
                    itemId: itemID,
                    statusRaw: ProcessingStatus.processing.rawValue,
                    attemptCount: 1,
                    lastError: nil,
                    submittedAt: now,
                    completedAt: nil
                ).insert(db)
            }
            try db.execute(
                sql: "UPDATE item SET processingStatusRaw = ? WHERE id = ?",
                arguments: [ProcessingStatus.processing.rawValue, itemID]
            )
        }
    }

    func finishAttempt(itemID: String, success: Bool, lastError: String?) async throws {
        try await dbWriter.write { db in
            let status: ProcessingStatus = success ? .done : .failed
            let now = Date().timeIntervalSince1970
            if var job = try ProcessingJob
                .filter(ProcessingJob.Columns.itemId == itemID)
                .fetchOne(db) {
                job.statusRaw = status.rawValue
                job.completedAt = now
                job.lastError = lastError
                try job.update(db)
            }
            try db.execute(
                sql: "UPDATE item SET processingStatusRaw = ? WHERE id = ?",
                arguments: [status.rawValue, itemID]
            )
        }
    }

    func resetStuckJobs() async throws {
        try await dbWriter.write { db in
            let now = Date().timeIntervalSince1970
            try db.execute(sql: """
                UPDATE processingJob
                   SET statusRaw = ?, lastError = ?, completedAt = ?
                 WHERE statusRaw = ?
                """, arguments: [
                    ProcessingStatus.failed.rawValue,
                    "Interrupted — please retry.",
                    now,
                    ProcessingStatus.processing.rawValue,
                ])
            try db.execute(sql: """
                UPDATE item SET processingStatusRaw = ? WHERE processingStatusRaw = ?
                """, arguments: [ProcessingStatus.failed.rawValue, ProcessingStatus.processing.rawValue])
        }
    }
}

private nonisolated struct SubmissionCounts: Decodable, FetchableRecord {
    var photoCount: Int
    var total: Int
    var ready: Int
}
