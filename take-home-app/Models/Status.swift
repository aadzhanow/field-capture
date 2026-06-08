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
