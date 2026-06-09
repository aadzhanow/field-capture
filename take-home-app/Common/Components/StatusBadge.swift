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
    /// Item-level badge for a gallery card.
    ///
    /// P2 only ever produces `notReady` right after save (derivatives pending),
    /// which §9 shows as "Assets Processing". The asset/age-aware distinctions
    /// (Assets Failed, Waiting Until Eligible, Ready to Process) and the full
    /// processing states land in P4/P5 as `AssetStatus` and the gates arrive.
    static func forGalleryItem(_ item: GalleryItem) -> StatusBadge {
        switch item.processingStatus {
        case .notReady:
            StatusBadge(text: "Assets Processing", systemImage: "clock.arrow.2.circlepath", tint: .orange)
        case .ready:
            StatusBadge(text: "Ready to Process", systemImage: "checkmark.circle", tint: .blue)
        case .processing:
            StatusBadge(text: "Processing", systemImage: "arrow.triangle.2.circlepath", tint: .blue)
        case .failed:
            StatusBadge(text: "Processing Failed", systemImage: "exclamationmark.triangle.fill", tint: .red)
        case .done:
            StatusBadge(text: "Done", systemImage: "checkmark.seal.fill", tint: .green)
        }
    }
}
