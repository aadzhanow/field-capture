//
//  ItemRepository.swift
//

import Foundation
import GRDB

final class ItemRepository {
    private let dbWriter: any DatabaseWriter

    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }

    func observeGalleryItems(
        onChange: @escaping @MainActor ([GalleryItem]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try ItemRepository.fetchGalleryItems(db)
        }
        return observation.start(
            in: dbWriter,
            onError: { error in MainActor.assumeIsolated { onError(error) } },
            onChange: { items in MainActor.assumeIsolated { onChange(items) } }
        )
    }

    nonisolated static func fetchGalleryItems(_ db: Database) throws -> [GalleryItem] {
        let rows = try GalleryItemRow.fetchAll(db, sql: """
            SELECT item.id, item.title, item.createdAt, item.processingStatusRaw,
                   COUNT(photo.id) AS photoCount,
                   (SELECT p.originalPath FROM photo p
                      WHERE p.itemId = item.id
                      ORDER BY p.sortOrder ASC LIMIT 1) AS representativeOriginalPath
              FROM item
              LEFT JOIN photo ON photo.itemId = item.id
             GROUP BY item.id
             ORDER BY item.createdAt DESC
            """)
        return rows.map(\.galleryItem)
    }

    #if DEBUG
    func insertDebugItem() async throws {
        let item = Item(
            id: UUID().uuidString,
            title: "Debug Item \(Int.random(in: 100...999))",
            notes: nil,
            createdAt: Date().timeIntervalSince1970,
            processingStatusRaw: ProcessingStatus.notReady.rawValue
        )
        try await dbWriter.write { db in
            try item.insert(db)
        }
    }
    #endif
}

private nonisolated struct GalleryItemRow: Decodable, FetchableRecord {
    var id: String
    var title: String
    var createdAt: Double
    var processingStatusRaw: String
    var photoCount: Int
    var representativeOriginalPath: String?

    var galleryItem: GalleryItem {
        GalleryItem(
            id: id,
            title: title,
            createdAt: Date(timeIntervalSince1970: createdAt),
            photoCount: photoCount,
            processingStatusRaw: processingStatusRaw,
            representativeOriginalPath: representativeOriginalPath
        )
    }
}
