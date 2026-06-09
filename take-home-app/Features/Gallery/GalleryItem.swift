//
//  GalleryItem.swift
//

import Foundation

nonisolated struct GalleryItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let photoCount: Int
    let processingStatusRaw: String
    let representativeCardPath: String?
    let representativeThumbnailPath: String?
    let derivativeTotal: Int
    let derivativeReady: Int
    let derivativeFailed: Int

    var processingStatus: ProcessingStatus {
        ProcessingStatus(rawValue: processingStatusRaw) ?? .notReady
    }

    var assetStatus: AssetStatus {
        AssetStatus.forItem(
            photoCount: photoCount,
            total: derivativeTotal,
            ready: derivativeReady,
            failed: derivativeFailed
        )
    }

    var representativeImagePaths: [String] {
        [representativeCardPath, representativeThumbnailPath].compactMap { $0 }
    }
}
