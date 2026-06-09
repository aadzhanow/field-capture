//
//  GalleryItem.swift
//

import Foundation

/// Read model for one gallery card. Built by `ItemRepository` from an item row
/// plus its photo aggregate and the representative photo's derivative paths.
nonisolated struct GalleryItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let photoCount: Int
    let processingStatusRaw: String
    /// `card`-kind derivative path for the representative photo; nil until ready.
    let representativeCardPath: String?
    /// `thumbnail`-kind derivative path for the representative photo; nil until ready.
    let representativeThumbnailPath: String?
    /// Aggregate derivative counts across all of the item's photos, for the
    /// derived item-level asset status.
    let derivativeTotal: Int
    let derivativeReady: Int
    let derivativeFailed: Int

    var processingStatus: ProcessingStatus {
        ProcessingStatus(rawValue: processingStatusRaw) ?? .notReady
    }

    /// Item-level asset status derived from the aggregate derivative counts.
    var assetStatus: AssetStatus {
        AssetStatus.forItem(
            photoCount: photoCount,
            total: derivativeTotal,
            ready: derivativeReady,
            failed: derivativeFailed
        )
    }

    /// Card image precedence: `card → thumbnail → placeholder`.
    var representativeImagePaths: [String] {
        [representativeCardPath, representativeThumbnailPath].compactMap { $0 }
    }
}
