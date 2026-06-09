//
//  StatusBadge.swift
//

import SwiftUI

struct StatusBadge: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: .capsule)
    }
}

extension StatusBadge {
    static func forItemListItem(_ item: ItemListItem) -> StatusBadge {
        forItem(processingStatus: item.processingStatus, assetStatus: item.assetStatus)
    }

    static func forItem(processingStatus: ProcessingStatus, assetStatus: AssetStatus) -> StatusBadge {
        switch processingStatus {
        case .ready:
            StatusBadge(text: "Ready to Process", systemImage: "checkmark.circle", tint: .blue)
        case .processing:
            StatusBadge(text: "Processing", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
        case .failed:
            StatusBadge(text: "Processing Failed", systemImage: "exclamationmark.triangle.fill", tint: .red)
        case .done:
            StatusBadge(text: "Done", systemImage: "checkmark.seal.fill", tint: .green)
        case .notReady:
            switch assetStatus {
            case .failed:
                StatusBadge(text: "Assets Failed", systemImage: "exclamationmark.triangle.fill", tint: .red)
            case .complete:
                StatusBadge(text: "Waiting Until Eligible", systemImage: "hourglass", tint: .orange)
            case .processing, .incomplete:
                StatusBadge(text: "Assets Processing", systemImage: "clock.arrow.2.circlepath", tint: .orange)
            }
        }
    }

    static func forAsset(_ status: AssetStatus) -> StatusBadge {
        switch status {
        case .complete:
            StatusBadge(text: "Complete", systemImage: "checkmark.circle.fill", tint: .green)
        case .processing:
            StatusBadge(text: "Processing", systemImage: "clock.arrow.2.circlepath", tint: .orange)
        case .incomplete:
            StatusBadge(text: "Incomplete", systemImage: "circle.dashed", tint: .secondary)
        case .failed:
            StatusBadge(text: "Failed", systemImage: "exclamationmark.triangle.fill", tint: .red)
        }
    }
}
