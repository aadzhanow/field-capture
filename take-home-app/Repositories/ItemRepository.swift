//
//  ItemRepository.swift
//

import Foundation
import GRDB

/// One captured photo's bytes + its capture position, handed to the save path.
/// Carries compressed JPEG `Data` (not a decoded bitmap), so a 25-photo draft
/// stays memory-light until it is staged to disk.
struct PhotoDraft: Sendable {
    let data: Data
    let sortOrder: Int
}

final class ItemRepository {
    private let dbWriter: any DatabaseWriter
    private let fileStorage: FileStorage

    init(dbWriter: any DatabaseWriter, fileStorage: FileStorage) {
        self.dbWriter = dbWriter
        self.fileStorage = fileStorage
    }

    // MARK: - Save (stage-then-commit)

    /// Creates an item with its photos using a **stage-then-commit** order. A
    /// SQLite transaction cannot enclose filesystem writes, so "one transaction"
    /// for files + rows is impossible; instead we stage originals first, then
    /// commit all rows atomically, guaranteeing §8's "no half-created items":
    ///
    /// 1. Stage every original to disk (`Data.write(.atomic)`).
    /// 2. Commit the `item` row + all `photo` rows + the pre-seeded 5×N `pending`
    ///    derivative matrix in **one** GRDB transaction.
    /// 3. On commit failure, delete the staged files and rethrow — nothing is
    ///    shown in the gallery.
    ///
    /// A crash between steps can only leave orphan files (rows committed = real
    /// item; no rows = junk files), which `RecoveryService` sweeps on launch.
    /// Returns the new item id so the caller can enqueue derivative generation.
    @discardableResult
    func createItem(title: String, notes: String?, photos: [PhotoDraft]) async throws -> String {
        let itemID = UUID().uuidString
        let now = Date().timeIntervalSince1970

        // 1. Stage originals to disk first, building the photo rows as we go.
        var stagedPaths: [String] = []
        var photoRows: [Photo] = []
        do {
            for draft in photos {
                let photoID = UUID().uuidString
                let relativePath = fileStorage.originalRelativePath(itemID: itemID, photoID: photoID)
                try fileStorage.write(draft.data, to: relativePath)
                stagedPaths.append(relativePath)
                photoRows.append(
                    Photo(
                        id: photoID,
                        itemId: itemID,
                        originalPath: relativePath,
                        sortOrder: draft.sortOrder,
                        createdAt: now
                    )
                )
            }
        } catch {
            stagedPaths.forEach { try? fileStorage.delete($0) }
            throw error
        }

        let item = Item(
            id: itemID,
            title: title,
            notes: notes,
            createdAt: now,
            processingStatusRaw: ProcessingStatus.notReady.rawValue
        )

        // 2. Commit item + photos + pre-seeded derivative matrix in one transaction.
        do {
            try await dbWriter.write { db in
                try item.insert(db)
                for photo in photoRows {
                    try photo.insert(db)
                    // Pre-seed all five derivative rows per photo as `pending`.
                    // The matrix of expected work lives in the DB from the start,
                    // so P3 generation and P6 recovery are "find pending rows",
                    // not guesswork.
                    for kind in DerivativeKind.allCases {
                        try Derivative(
                            id: UUID().uuidString,
                            photoId: photo.id,
                            kind: kind.rawValue,
                            path: nil,
                            byteCount: nil,
                            statusRaw: DerivativeStatus.pending.rawValue
                        ).insert(db)
                    }
                }
            }
        } catch {
            // 3. DB commit failed → sweep staged files, surface as save failure.
            stagedPaths.forEach { try? fileStorage.delete($0) }
            throw error
        }

        return itemID
    }

    // MARK: - Observation (read)

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
        // The card's representative image is the first photo by capture order
        // (`min(sortOrder)`). We surface its `card` and `thumbnail` derivative
        // paths (only when `ready`) so the card upgrades live as derivatives land
        // (precedence: card → thumbnail → placeholder). Both are null until P3
        // generation completes.
        let rows = try GalleryItemRow.fetchAll(db, sql: """
            SELECT item.id, item.title, item.createdAt, item.processingStatusRaw,
                   COUNT(photo.id) AS photoCount,
                   (SELECT d.path FROM derivative d
                      WHERE d.photoId = (SELECT p.id FROM photo p
                                           WHERE p.itemId = item.id
                                           ORDER BY p.sortOrder ASC LIMIT 1)
                        AND d.kind = 'card' AND d.statusRaw = 'ready'
                      LIMIT 1) AS representativeCardPath,
                   (SELECT d.path FROM derivative d
                      WHERE d.photoId = (SELECT p.id FROM photo p
                                           WHERE p.itemId = item.id
                                           ORDER BY p.sortOrder ASC LIMIT 1)
                        AND d.kind = 'thumbnail' AND d.statusRaw = 'ready'
                      LIMIT 1) AS representativeThumbnailPath
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
    var representativeCardPath: String?
    var representativeThumbnailPath: String?

    var galleryItem: GalleryItem {
        GalleryItem(
            id: id,
            title: title,
            createdAt: Date(timeIntervalSince1970: createdAt),
            photoCount: photoCount,
            processingStatusRaw: processingStatusRaw,
            representativeCardPath: representativeCardPath,
            representativeThumbnailPath: representativeThumbnailPath
        )
    }
}
