//
//  Photo.swift
//

import Foundation
import GRDB

nonisolated struct Photo: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: String
    var itemId: String
    /// Relative path under file storage.
    var originalPath: String
    /// Capture order; the representative photo is `min(sortOrder)`.
    var sortOrder: Int
    var createdAt: Double

    static let databaseTableName = "photo"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let itemId = Column(CodingKeys.itemId)
        static let sortOrder = Column(CodingKeys.sortOrder)
    }
}
