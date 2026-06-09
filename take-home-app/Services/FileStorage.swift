//
//  FileStorage.swift
//

import Foundation

/// Filesystem boundary for image bytes. Image data lives as **files**, never as
/// DB blobs (§2). Everything here speaks **relative** paths — absolute container
/// URLs break across reinstall/restore because the container UUID changes while
/// the DB persists (a silent data-loss bug). This type owns the base-URL
/// resolution and is the only place a relative path becomes an absolute `URL`.
/// Requirements are `nonisolated` because file work runs off the main actor
/// (the derivative pipeline, image decoding). Under the project's MainActor
/// default isolation, an unannotated requirement would be main-actor-bound.
protocol FileStorage: Sendable {
    /// Absolute URL for a stored relative path (resolved against the base dir).
    nonisolated func url(for relativePath: String) -> URL

    /// Writes `data` atomically (temp file + rename) at `relativePath`, creating
    /// intermediate directories. Returns the same relative path for convenience.
    @discardableResult
    nonisolated func write(_ data: Data, to relativePath: String) throws -> String

    nonisolated func read(_ relativePath: String) throws -> Data
    nonisolated func delete(_ relativePath: String) throws
    nonisolated func exists(_ relativePath: String) -> Bool

    /// Relative paths of every file currently under storage, for the launch-time
    /// orphan sweep (files with no matching DB row).
    nonisolated func allStoredRelativePaths() throws -> [String]

    /// Stable relative path for an original image, grouped by item so an item's
    /// files can be swept in one shot.
    nonisolated func originalRelativePath(itemID: String, photoID: String) -> String

    /// Stable relative path for a generated derivative file.
    nonisolated func derivativeRelativePath(itemID: String, photoID: String, kind: DerivativeKind) -> String
}

/// On-disk `FileStorage`. Base dir is `Application Support/Images`. No shared
/// mutable state, so it is safely `Sendable` and usable from the derivative
/// pipeline (background) and image loading (main) alike.
nonisolated final class DiskFileStorage: FileStorage, @unchecked Sendable {
    /// Absolute base directory. Stored relative paths are resolved against this.
    private let baseURL: URL
    private let fileManager = FileManager.default

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.baseURL = appSupport.appendingPathComponent(Constants.imagesDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func url(for relativePath: String) -> URL {
        baseURL.appendingPathComponent(relativePath)
    }

    @discardableResult
    func write(_ data: Data, to relativePath: String) throws -> String {
        let fileURL = url(for: relativePath)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // `.atomic` writes to a temp file and renames into place, so a crash
        // mid-write can never leave a partially written file readable as valid.
        try data.write(to: fileURL, options: .atomic)
        return relativePath
    }

    func read(_ relativePath: String) throws -> Data {
        try Data(contentsOf: url(for: relativePath))
    }

    func delete(_ relativePath: String) throws {
        let fileURL = url(for: relativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func exists(_ relativePath: String) -> Bool {
        fileManager.fileExists(atPath: url(for: relativePath).path)
    }

    func allStoredRelativePaths() throws -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return []
        }
        let basePrefix = baseURL.standardizedFileURL.path
        var paths: [String] = []
        for case let fileURL as URL in enumerator {
            let isFile = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            guard isFile else { continue }
            var path = fileURL.standardizedFileURL.path
            guard path.hasPrefix(basePrefix) else { continue }
            path.removeFirst(basePrefix.count)
            while path.hasPrefix("/") { path.removeFirst() }
            paths.append(path)
        }
        return paths
    }

    func originalRelativePath(itemID: String, photoID: String) -> String {
        "\(Constants.originalsDirectoryName)/\(itemID)/\(photoID).jpg"
    }

    func derivativeRelativePath(itemID: String, photoID: String, kind: DerivativeKind) -> String {
        "\(Constants.derivativesDirectoryName)/\(itemID)/\(photoID)/\(kind.rawValue).jpg"
    }
}
