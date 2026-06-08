//
//  Derivative.swift
//

import Foundation
import GRDB

nonisolated struct Derivative: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: String
    var photoId: String
    var kind: String
    /// Relative path; nil until the derivative is ready.
    var path: String?
    var byteCount: Int?
    var statusRaw: String

    static let databaseTableName = "derivative"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let photoId = Column(CodingKeys.photoId)
        static let kind = Column(CodingKeys.kind)
        static let statusRaw = Column(CodingKeys.statusRaw)
    }
}

extension Derivative {
    var kindEnum: DerivativeKind? {
        DerivativeKind(rawValue: kind)
    }

    var status: DerivativeStatus {
        DerivativeStatus(rawValue: statusRaw) ?? .pending
    }
}
