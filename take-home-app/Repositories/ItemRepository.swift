//
//  ItemRepository.swift
//

import Foundation
import GRDB

/// One captured photo's bytes + its capture position, handed to the save path.
/// Carries compressed JPEG `Data` (not a decoded bitmap), so a 25-photo draft
/// stays memory-light until it is staged to disk.
nonisolated struct PhotoDraft: Sendable {
    let data: Data
    let sortOrder: Int
}

/// One unit of derivative work for the pipeline: which derivative row to fill,
/// from which original file, at which size.
nonisolated struct DerivativeWork: Sendable {
    let derivativeID: String
    let photoID: String
    let originalPath: String
    let kind: DerivativeKind
}

/// `nonisolated` + `Sendable`: this is a stateless wrapper over a Sendable
/// `DatabaseWriter` and `FileStorage`, used from the main actor (gallery VM) and
/// from the `ProcessingEngine` actor alike. Its async DB calls hop to GRDB's
/// own queue, so heavy save/generation work never runs on the main actor.
nonisolated final class ItemRepository: Sendable {
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
                    // so generation and recovery are "find pending rows", not
                    // guesswork.
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

    // MARK: - Derivative pipeline support

    /// All not-yet-ready derivative rows for an item (status `pending` or
    /// `failed`), ordered so the representative photo and its smaller derivatives
    /// generate first — the gallery thumbnail then upgrades fastest.
    func pendingDerivativeWork(itemID: String) async throws -> [DerivativeWork] {
        try await dbWriter.read { db in
            let rows = try DerivativeWorkRow.fetchAll(db, sql: """
                SELECT d.id AS derivativeID, p.id AS photoID,
                       p.originalPath AS originalPath, d.kind AS kind
                  FROM derivative d
                  JOIN photo p ON p.id = d.photoId
                 WHERE p.itemId = ? AND d.statusRaw IN ('pending', 'failed')
                 ORDER BY p.sortOrder ASC,
                          CASE d.kind
                              WHEN 'thumbnail' THEN 0
                              WHEN 'card' THEN 1
                              WHEN 'preview' THEN 2
                              WHEN 'detail' THEN 3
                              ELSE 4
                          END ASC
                """, arguments: [itemID])
            return rows.compactMap { row in
                guard let kind = DerivativeKind(rawValue: row.kind) else { return nil }
                return DerivativeWork(
                    derivativeID: row.derivativeID,
                    photoID: row.photoID,
                    originalPath: row.originalPath,
                    kind: kind
                )
            }
        }
    }

    func markDerivativeReady(id: String, path: String, byteCount: Int) async throws {
        try await dbWriter.write { db in
            try db.execute(sql: """
                UPDATE derivative SET statusRaw = ?, path = ?, byteCount = ? WHERE id = ?
                """, arguments: [DerivativeStatus.ready.rawValue, path, byteCount, id])
        }
    }

    func markDerivativeFailed(id: String) async throws {
        try await dbWriter.write { db in
            try db.execute(sql: """
                UPDATE derivative SET statusRaw = ?, path = NULL, byteCount = NULL WHERE id = ?
                """, arguments: [DerivativeStatus.failed.rawValue, id])
        }
    }

    /// After generation, move a pre-submission item to `ready` when every photo is
    /// derivative-complete and the 8h window has passed, else keep it `notReady`.
    /// Never touches `processing`/`failed`/`done` — those are owned by the
    /// processing flow (P5) and `done` is terminal.
    func recomputeProcessingStatus(itemID: String) async throws {
        try await dbWriter.write { db in
            try Self.recomputeProcessingStatus(db, itemID: itemID)
        }
    }

    /// Pre-submission status recompute, runnable inside a transaction. Moves a
    /// `notReady`/`ready` item to `ready` when derivative-complete **and** past
    /// `eligibleAt`, else `notReady`. Never touches `processing`/`failed`/`done`.
    static func recomputeProcessingStatus(_ db: Database, itemID: String) throws {
        guard var item = try Item.fetchOne(db, key: itemID) else { return }
        let status = ProcessingStatus(rawValue: item.processingStatusRaw) ?? .notReady
        guard status == .notReady || status == .ready else { return }

        let counts = try StatusCounts.fetchOne(db, sql: """
            SELECT COUNT(*) AS total,
                   COALESCE(SUM(CASE WHEN d.statusRaw = 'ready' THEN 1 ELSE 0 END), 0) AS ready
              FROM derivative d
              JOIN photo p ON p.id = d.photoId
             WHERE p.itemId = ?
            """, arguments: [itemID]) ?? StatusCounts(total: 0, ready: 0)

        let complete = counts.total > 0 && counts.ready == counts.total
        let eligible = Date().timeIntervalSince1970 >= item.createdAt + Constants.eligibilityWindow
        let newStatus: ProcessingStatus = (complete && eligible) ? .ready : .notReady

        if newStatus.rawValue != item.processingStatusRaw {
            item.processingStatusRaw = newStatus.rawValue
            try item.update(db)
        }
    }

    /// Debug "make eligible": back-date `createdAt` just past the 8h window and
    /// recompute, so a complete item flips to `Ready to Process` immediately —
    /// no real wait. A DB write, so it flows through `ValueObservation`.
    func makeEligible(itemID: String) async throws {
        try await dbWriter.write { db in
            let backDated = Date().timeIntervalSince1970 - Constants.eligibilityWindow - 60
            try db.execute(
                sql: "UPDATE item SET createdAt = ? WHERE id = ?",
                arguments: [backDated, itemID]
            )
            try Self.recomputeProcessingStatus(db, itemID: itemID)
        }
    }

    /// Promote every complete, now-eligible `notReady` item to `ready` in one
    /// statement. `ValueObservation` fires on DB writes (not the wall clock), so
    /// the gallery/detail timers call this to flip badges when the window passes.
    func promoteEligibleItems() async throws {
        try await dbWriter.write { db in
            try db.execute(sql: """
                UPDATE item SET processingStatusRaw = 'ready'
                 WHERE processingStatusRaw = 'notReady'
                   AND (createdAt + ?) <= ?
                   AND EXISTS (SELECT 1 FROM photo WHERE photo.itemId = item.id)
                   AND NOT EXISTS (
                       SELECT 1 FROM derivative d JOIN photo p ON p.id = d.photoId
                        WHERE p.itemId = item.id AND d.statusRaw <> 'ready')
                """, arguments: [Constants.eligibilityWindow, Date().timeIntervalSince1970])
        }
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

    static func fetchGalleryItems(_ db: Database) throws -> [GalleryItem] {
        // The card's representative image is the first photo by capture order
        // (`min(sortOrder)`). We surface its `card` and `thumbnail` derivative
        // paths (only when `ready`) so the card upgrades live as derivatives land
        // (precedence: card → thumbnail → placeholder).
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
                      LIMIT 1) AS representativeThumbnailPath,
                   (SELECT COUNT(*) FROM derivative d
                      JOIN photo p ON p.id = d.photoId
                     WHERE p.itemId = item.id) AS derivativeTotal,
                   (SELECT COUNT(*) FROM derivative d
                      JOIN photo p ON p.id = d.photoId
                     WHERE p.itemId = item.id AND d.statusRaw = 'ready') AS derivativeReady,
                   (SELECT COUNT(*) FROM derivative d
                      JOIN photo p ON p.id = d.photoId
                     WHERE p.itemId = item.id AND d.statusRaw = 'failed') AS derivativeFailed
              FROM item
              LEFT JOIN photo ON photo.itemId = item.id
             GROUP BY item.id
             ORDER BY item.createdAt DESC
            """)
        return rows.map(\.galleryItem)
    }

    func observeItemDetail(
        itemID: String,
        onChange: @escaping @MainActor (ItemDetail?) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try ItemRepository.fetchItemDetail(db, itemID: itemID)
        }
        return observation.start(
            in: dbWriter,
            onError: { error in MainActor.assumeIsolated { onError(error) } },
            onChange: { detail in MainActor.assumeIsolated { onChange(detail) } }
        )
    }

    static func fetchItemDetail(_ db: Database, itemID: String) throws -> ItemDetail? {
        guard let item = try Item.fetchOne(db, key: itemID) else { return nil }

        let photos = try Photo
            .filter(Photo.Columns.itemId == itemID)
            .order(Photo.Columns.sortOrder)
            .fetchAll(db)
        let derivatives = try Derivative
            .filter(photos.map(\.id).contains(Derivative.Columns.photoId))
            .fetchAll(db)
        let byPhoto = Dictionary(grouping: derivatives, by: \.photoId)

        // Stable ordering by DerivativeKind declaration order.
        let order = Dictionary(
            uniqueKeysWithValues: DerivativeKind.allCases.enumerated().map { ($1.rawValue, $0) }
        )
        let detailPhotos = photos.map { photo in
            let rows = (byPhoto[photo.id] ?? [])
                .sorted { (order[$0.kind] ?? .max) < (order[$1.kind] ?? .max) }
                .compactMap { derivative -> DetailDerivative? in
                    guard let kind = derivative.kindEnum else { return nil }
                    return DetailDerivative(
                        id: derivative.id,
                        kind: kind,
                        status: derivative.status,
                        path: derivative.path,
                        byteCount: derivative.byteCount
                    )
                }
            return DetailPhoto(id: photo.id, sortOrder: photo.sortOrder, derivatives: rows)
        }

        let job = try ProcessingJob
            .filter(ProcessingJob.Columns.itemId == itemID)
            .fetchOne(db)

        return ItemDetail(
            id: item.id,
            title: item.title,
            notes: item.notes,
            createdAt: item.createdDate,
            eligibleAt: item.eligibleAt,
            processingStatusRaw: item.processingStatusRaw,
            photos: detailPhotos,
            lastError: job?.lastError,
            attemptCount: job?.attemptCount ?? 0
        )
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
    var derivativeTotal: Int
    var derivativeReady: Int
    var derivativeFailed: Int

    var galleryItem: GalleryItem {
        GalleryItem(
            id: id,
            title: title,
            createdAt: Date(timeIntervalSince1970: createdAt),
            photoCount: photoCount,
            processingStatusRaw: processingStatusRaw,
            representativeCardPath: representativeCardPath,
            representativeThumbnailPath: representativeThumbnailPath,
            derivativeTotal: derivativeTotal,
            derivativeReady: derivativeReady,
            derivativeFailed: derivativeFailed
        )
    }
}

private nonisolated struct DerivativeWorkRow: Decodable, FetchableRecord {
    var derivativeID: String
    var photoID: String
    var originalPath: String
    var kind: String
}

private nonisolated struct StatusCounts: Decodable, FetchableRecord {
    var total: Int
    var ready: Int
}
