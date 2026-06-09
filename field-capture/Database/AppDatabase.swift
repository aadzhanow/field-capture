//
//  AppDatabase.swift
//

import Foundation
import GRDB

final class AppDatabase {
    let dbWriter: any DatabaseWriter

    init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "item") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("notes", .text)
                t.column("createdAt", .double).notNull().indexed()
                t.column("processingStatusRaw", .text).notNull()
            }

            try db.create(table: "photo") { t in
                t.primaryKey("id", .text)
                t.column("itemId", .text).notNull()
                    .indexed()
                    .references("item", onDelete: .cascade)
                t.column("originalPath", .text).notNull()
                t.column("sortOrder", .integer).notNull()
                t.column("createdAt", .double).notNull()
            }

            try db.create(table: "derivative") { t in
                t.primaryKey("id", .text)
                t.column("photoId", .text).notNull()
                    .indexed()
                    .references("photo", onDelete: .cascade)
                t.column("kind", .text).notNull()
                t.column("path", .text)
                t.column("byteCount", .integer)
                t.column("statusRaw", .text).notNull()
                t.uniqueKey(["photoId", "kind"])
            }

            try db.create(table: "processingJob") { t in
                t.primaryKey("id", .text)
                t.column("itemId", .text).notNull()
                    .indexed()
                    .references("item", onDelete: .cascade)
                t.column("statusRaw", .text).notNull()
                t.column("attemptCount", .integer).notNull().defaults(to: 0)
                t.column("lastError", .text)
                t.column("submittedAt", .double)
                t.column("completedAt", .double)
            }
        }

        return migrator
    }
}

extension AppDatabase {
    static func makeShared() throws -> AppDatabase {
        let fileManager = FileManager.default
        let documents = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = documents.appendingPathComponent(Constants.databaseFileName)
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        return try AppDatabase(dbQueue)
    }
}
