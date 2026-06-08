//
//  Item.swift
//

import Foundation
import GRDB

nonisolated struct Item: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: String
    var title: String
    var notes: String?
    /// UTC epoch seconds.
    var createdAt: Double
    var processingStatusRaw: String

    static let databaseTableName = "item"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let createdAt = Column(CodingKeys.createdAt)
        static let processingStatusRaw = Column(CodingKeys.processingStatusRaw)
    }
}

extension Item {
    var processingStatus: ProcessingStatus {
        ProcessingStatus(rawValue: processingStatusRaw) ?? .notReady
    }

    var createdDate: Date {
        Date(timeIntervalSince1970: createdAt)
    }

    var eligibleAt: Date {
        Date(timeIntervalSince1970: createdAt + Constants.eligibilityWindow)
    }
}
