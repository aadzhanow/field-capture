//
//  FileStorage.swift
//

import Foundation

// Requirements are `nonisolated`: file work runs off the main actor; under the
// project's MainActor default an unannotated requirement would be main-actor-bound.
protocol FileStorage: Sendable {
    nonisolated func url(for relativePath: String) -> URL

    @discardableResult
    nonisolated func write(_ data: Data, to relativePath: String) throws -> String

    nonisolated func read(_ relativePath: String) throws -> Data
    nonisolated func delete(_ relativePath: String) throws
    nonisolated func exists(_ relativePath: String) -> Bool

    nonisolated func allStoredRelativePaths() throws -> [String]

    nonisolated func originalRelativePath(itemID: String, photoID: String) -> String

    nonisolated func derivativeRelativePath(itemID: String, photoID: String, kind: DerivativeKind) -> String
}

nonisolated final class DiskFileStorage: FileStorage, @unchecked Sendable {
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
        try data.write(to: fileURL, options: .atomic) // atomic: crash mid-write leaves no partial file
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
