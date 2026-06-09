//
//  Status.swift
//

import Foundation

/// The five derivatives generated per original image. Declaration order is `allCases` order.
enum DerivativeKind: String, CaseIterable, Codable, Sendable {
    case thumbnail
    case card
    case preview
    case detail
    case processing

    var maxLongEdge: Int {
        switch self {
        case .thumbnail: 160
        case .card:      360
        case .preview:   720
        case .detail:    1280
        case .processing: 1920
        }
    }
}

enum DerivativeStatus: String, Codable, Sendable {
    case pending
    case ready
    case failed
}

/// `notReady -> ready -> processing -> failed (retry) | done (terminal)`
enum ProcessingStatus: String, Codable, Sendable {
    case notReady
    case ready
    case processing
    case failed
    case done
}

/// Derived over a photo's five derivative rows — never persisted.
enum AssetStatus: Sendable {
    case processing
    case failed
    case incomplete
    case complete
}

extension AssetStatus {
    /// Photo-level: derived from a photo's derivative statuses. An over-limit
    /// derivative is already persisted as `failed` by the generator, so it lands
    /// here as `.failed` rather than silently looping.
    /// Precedence: failed > incomplete (missing rows) > processing (pending) > complete.
    nonisolated static func forPhoto(statuses: [DerivativeStatus]) -> AssetStatus {
        let expected = DerivativeKind.allCases.count
        if statuses.contains(.failed) { return .failed }
        if statuses.count < expected { return .incomplete }
        return statuses.allSatisfy { $0 == .ready } ? .complete : .processing
    }

    /// Item-level: derived from aggregate derivative counts across all photos.
    /// An item is asset-complete only when every photo has all five derivatives
    /// ready (§6 derivative-completeness gate).
    nonisolated static func forItem(photoCount: Int, total: Int, ready: Int, failed: Int) -> AssetStatus {
        let expected = photoCount * DerivativeKind.allCases.count
        if failed > 0 { return .failed }
        if photoCount == 0 || total < expected { return .incomplete }
        return ready == expected ? .complete : .processing
    }
}
