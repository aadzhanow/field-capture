//
//  ItemDetail.swift
//

import Foundation

/// Read model for the item detail screen, rebuilt by `ItemRepository` on every
/// relevant DB change so the screen updates live as derivatives land.
nonisolated struct ItemDetail: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let createdAt: Date
    let eligibleAt: Date
    let processingStatusRaw: String
    let photos: [DetailPhoto]

    var processingStatus: ProcessingStatus {
        ProcessingStatus(rawValue: processingStatusRaw) ?? .notReady
    }

    /// Item-level asset status: the aggregate of the per-photo statuses.
    /// Precedence mirrors §6: failed > incomplete > processing > complete.
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
    /// The photo's derivative rows, ordered by `DerivativeKind` declaration order.
    let derivatives: [DetailDerivative]

    var assetStatus: AssetStatus {
        AssetStatus.forPhoto(statuses: derivatives.map(\.status))
    }

    /// Large display image — prefers larger derivatives, **never the original**.
    var displayImagePaths: [String] {
        readyPaths(for: [.detail, .preview, .card, .thumbnail])
    }

    /// Thumbnail-strip image.
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
