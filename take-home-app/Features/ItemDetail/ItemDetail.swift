//
//  ItemDetail.swift
//

import Foundation

nonisolated struct ItemDetail: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let createdAt: Date
    let eligibleAt: Date
    let processingStatusRaw: String
    let photos: [DetailPhoto]
    let lastError: String?
    let attemptCount: Int

    var processingStatus: ProcessingStatus {
        ProcessingStatus(rawValue: processingStatusRaw) ?? .notReady
    }

    var assetStatus: AssetStatus {
        let perPhoto = photos.map(\.assetStatus)
        if perPhoto.contains(.failed) { return .failed }
        if perPhoto.contains(.incomplete) { return .incomplete }
        if perPhoto.contains(.processing) { return .processing }
        return photos.isEmpty ? .incomplete : .complete
    }
}

nonisolated struct DetailPhoto: Identifiable, Equatable, Sendable {
    let id: String
    let sortOrder: Int
    let derivatives: [DetailDerivative]

    var assetStatus: AssetStatus {
        AssetStatus.forPhoto(statuses: derivatives.map(\.status))
    }

    var displayImagePaths: [String] {
        readyPaths(for: [.detail, .preview, .card, .thumbnail])
    }

    var thumbnailImagePaths: [String] {
        readyPaths(for: [.thumbnail, .card, .preview])
    }

    private func readyPaths(for kinds: [DerivativeKind]) -> [String] {
        kinds.compactMap { kind in
            derivatives.first { $0.kind == kind && $0.status == .ready }?.path
        }
    }
}

nonisolated struct DetailDerivative: Identifiable, Equatable, Sendable {
    let id: String
    let kind: DerivativeKind
    let status: DerivativeStatus
    let path: String?
    let byteCount: Int?
}
