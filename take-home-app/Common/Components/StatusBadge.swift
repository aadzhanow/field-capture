//
//  StatusBadge.swift
//

import SwiftUI

/// Shared status pill used on gallery cards and (later) item detail. Pure value
/// in → view out, so it previews in isolation.
struct StatusBadge: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: .capsule)
    }
}

extension StatusBadge {
    static func forGalleryItem(_ item: GalleryItem) -> StatusBadge {
        forItem(processingStatus: item.processingStatus, assetStatus: item.assetStatus)
    }

    /// The item-level §9 badge. The processing states take precedence; while the
    /// item is still `notReady` the badge reflects the derived asset status —
    /// "Assets Failed" if any derivative failed, "Assets Processing" while still
    /// generating, and "Waiting Until Eligible" once assets are complete but the
    /// 8h window hasn't passed (a complete item is only `notReady` when young).
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

    /// Asset-level pill for the detail screen (per-photo and item header).
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
