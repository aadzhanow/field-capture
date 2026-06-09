//
//  Status.swift
//

import Foundation

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

enum ProcessingStatus: String, Codable, Sendable {
    case notReady
    case ready
    case processing
    case failed
    case done
}

enum AssetStatus: Sendable {
    case processing
    case failed
    case incomplete
    case complete
}

extension AssetStatus {
    nonisolated static func forPhoto(statuses: [DerivativeStatus]) -> AssetStatus {
        let expected = DerivativeKind.allCases.count
        if statuses.contains(.failed) { return .failed }
        if statuses.count < expected { return .incomplete }
        return statuses.allSatisfy { $0 == .ready } ? .complete : .processing
    }

    nonisolated static func forItem(photoCount: Int, total: Int, ready: Int, failed: Int) -> AssetStatus {
        let expected = photoCount * DerivativeKind.allCases.count
        if failed > 0 { return .failed }
        if photoCount == 0 || total < expected { return .incomplete }
        return ready == expected ? .complete : .processing
    }
}
