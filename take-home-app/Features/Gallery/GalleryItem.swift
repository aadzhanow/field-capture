//
//  GalleryItem.swift
//

import Foundation

/// Read model for one gallery card. Built by `ItemRepository` from an item row
/// plus its photo aggregate.
nonisolated struct GalleryItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let photoCount: Int
    let processingStatusRaw: String
    let representativeOriginalPath: String?

    var processingStatus: ProcessingStatus {
        ProcessingStatus(rawValue: processingStatusRaw) ?? .notReady
    }
}
