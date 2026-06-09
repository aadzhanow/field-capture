//
//  ItemRepository.swift
//

import Foundation
import GRDB

nonisolated struct PhotoDraft: Sendable {
    let data: Data
    let sortOrder: Int
}

nonisolated struct DerivativeWork: Sendable {
    let derivativeID: String
    let photoID: String
    let originalPath: String
    let kind: DerivativeKind
}

nonisolated struct DerivativeFileRef: Decodable, FetchableRecord, Sendable {
    var id: String
    var path: String
}

nonisolated final class ItemRepository: Sendable {
    private let dbWriter: any DatabaseWriter
    private let fileStorage: FileStorage

    init(dbWriter: any DatabaseWriter, fileStorage: FileStorage) {
        self.dbWriter = dbWriter
        self.fileStorage = fileStorage
    }

    // MARK: - Save (stage-then-commit)

    @discardableResult
    func createItem(title: String, notes: String?, photos: [PhotoDraft]) async throws -> String {
        let itemID = UUID().uuidString
        let now = Date().timeIntervalSince1970

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

        let rows = photoRows
        do {
            try await dbWriter.write { db in
                try item.insert(db)
                for photo in rows {
                    try photo.insert(db)
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
            stagedPaths.forEach { try? fileStorage.delete($0) }
            throw error
        }

        Log.dataInfo("Saved item \(itemID) with \(rows.count) photo(s)")
        return itemID
    }

    // MARK: - Delete

    func deleteItem(id: String) async throws {
        try await dbWriter.write { db in
            try db.execute(sql: "DELETE FROM item WHERE id = ?", arguments: [id])
        }
        fileStorage.deleteItemFiles(itemID: id)
        Log.dataInfo("Deleted item \(id)")
    }

    // MARK: - Derivative pipeline support

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

    func recomputeProcessingStatus(itemID: String) async throws {
        try await dbWriter.write { db in
            try Self.recomputeProcessingStatus(db, itemID: itemID)
        }
    }

    static func recomputeProcessingStatus(_ db: Database, itemID: String) throws {
        guard var item = try Item.fetchOne(db, key: itemID) else { return }
        let status = ProcessingStatus(rawValue: item.processingStatusRaw) ?? .notReady
        guard status == .notReady || status == .ready else { return }

        let complete = try isDerivativeComplete(db, itemID: itemID)
        let eligible = Date().timeIntervalSince1970 >= item.createdAt + Constants.eligibilityWindow
        let newStatus: ProcessingStatus = (complete && eligible) ? .ready : .notReady

        if newStatus.rawValue != item.processingStatusRaw {
            item.processingStatusRaw = newStatus.rawValue
            try item.update(db)
        }
    }

    static func isDerivativeComplete(_ db: Database, itemID: String) throws -> Bool {
        let counts = try CompletionCounts.fetchOne(db, sql: """
            SELECT (SELECT COUNT(*) FROM photo WHERE itemId = :id) AS photoCount,
                   (SELECT COUNT(*) FROM derivative d JOIN photo p ON p.id = d.photoId
                      WHERE p.itemId = :id AND d.statusRaw = 'ready'
                        AND d.path IS NOT NULL AND d.byteCount <= :cap) AS readyValid
            """, arguments: ["id": itemID, "cap": Constants.maxDerivativeBytes])
            ?? CompletionCounts(photoCount: 0, readyValid: 0)
        return counts.photoCount > 0
            && counts.readyValid == counts.photoCount * DerivativeKind.allCases.count
    }

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

    func promoteEligibleItems() async throws {
        try await dbWriter.write { db in
            let notReadyIDs = try String.fetchAll(
                db, sql: "SELECT id FROM item WHERE processingStatusRaw = 'notReady'"
            )
            for id in notReadyIDs {
                try Self.recomputeProcessingStatus(db, itemID: id)
            }
        }
    }

    // MARK: - Recovery support

    func readyDerivativeFileRefs() async throws -> [DerivativeFileRef] {
        try await dbWriter.read { db in
            try DerivativeFileRef.fetchAll(db, sql: """
                SELECT id, path FROM derivative WHERE statusRaw = 'ready' AND path IS NOT NULL
                """)
        }
    }

    func markDerivativesPending(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await dbWriter.write { db in
            try db.execute(sql: """
                UPDATE derivative SET statusRaw = 'pending', path = NULL, byteCount = NULL
                 WHERE id IN (\(databaseQuestionMarks(count: ids.count)))
                """, arguments: StatementArguments(ids))
        }
    }

    func itemIDsWithUnfinishedDerivatives() async throws -> [String] {
        try await dbWriter.read { db in
            try String.fetchAll(db, sql: """
                SELECT DISTINCT p.itemId FROM derivative d
                  JOIN photo p ON p.id = d.photoId
                 WHERE d.statusRaw IN ('pending', 'failed')
                """)
        }
    }

    // MARK: - Observation (read)

    @MainActor
    func observeItemListItems(
        onChange: @escaping @MainActor ([ItemListItem]) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try ItemRepository.fetchItemListItems(db)
        }
        return observation.start(
            in: dbWriter,
            onError: { error in MainActor.assumeIsolated { onError(error) } },
            onChange: { items in MainActor.assumeIsolated { onChange(items) } }
        )
    }

    static func fetchItemListItems(_ db: Database) throws -> [ItemListItem] {
        let rows = try ItemListItemRow.fetchAll(db, sql: """
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

    @MainActor
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

}

private nonisolated struct ItemListItemRow: Decodable, FetchableRecord {
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

    var galleryItem: ItemListItem {
        ItemListItem(
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

private nonisolated struct CompletionCounts: Decodable, FetchableRecord {
    var photoCount: Int
    var readyValid: Int
}
