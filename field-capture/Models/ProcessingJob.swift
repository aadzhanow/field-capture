//
//  ProcessingJob.swift
//

import Foundation
import GRDB

nonisolated struct ProcessingJob: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: String
    var itemId: String
    var statusRaw: String
    var attemptCount: Int
    var lastError: String?
    var submittedAt: Double?
    var completedAt: Double?

    static let databaseTableName = "processingJob"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let itemId = Column(CodingKeys.itemId)
        static let statusRaw = Column(CodingKeys.statusRaw)
    }
}
