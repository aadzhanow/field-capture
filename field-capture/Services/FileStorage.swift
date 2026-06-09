//
//  FileStorage.swift
//

import Foundation

nonisolated final class FileStorage: @unchecked Sendable {
    private let baseURL: URL
    private let fileManager = FileManager.default

    init() throws {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.baseURL = documents.appendingPathComponent(Constants.imagesDirectoryName, isDirectory: true)
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

    func originalRelativePath(itemID: String, photoID: String) -> String {
        "\(Constants.originalsDirectoryName)/\(itemID)/\(photoID).jpg"
    }

    func derivativeRelativePath(itemID: String, photoID: String, kind: DerivativeKind) -> String {
        "\(Constants.derivativesDirectoryName)/\(itemID)/\(photoID)/\(kind.rawValue).jpg"
    }

    func deleteItemFiles(itemID: String) {
        try? delete("\(Constants.originalsDirectoryName)/\(itemID)")
        try? delete("\(Constants.derivativesDirectoryName)/\(itemID)")
    }
}
