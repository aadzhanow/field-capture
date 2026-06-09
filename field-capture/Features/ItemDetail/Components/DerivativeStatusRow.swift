//
//  DerivativeStatusRow.swift
//

import SwiftUI

struct DerivativeStatusRow: View {
    let photo: DetailPhoto
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photo \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge.forAsset(photo.assetStatus)
            }
            HStack(spacing: 6) {
                ForEach(photo.derivatives) { derivative in
                    DerivativeChip(derivative: derivative)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DerivativeChip: View {
    let derivative: DetailDerivative

    var body: some View {
        VStack(spacing: 3) {
            Text(kindLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
            Image(systemName: statusIcon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(detailLabel)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private var kindLabel: String {
        switch derivative.kind {
        case .thumbnail: "Thumb"
        case .card: "Card"
        case .preview: "Preview"
        case .detail: "Detail"
        case .processing: "Process"
        }
    }

    private var statusIcon: String {
        switch derivative.status {
        case .pending: "clock"
        case .ready: "checkmark"
        case .failed: "xmark"
        }
    }

    private var detailLabel: String {
        switch derivative.status {
        case .ready:
            if let bytes = derivative.byteCount { "\(bytes / 1000)KB" } else { "ready" }
        case .pending: "pending"
        case .failed: "failed"
        }
    }

    private var tint: Color {
        switch derivative.status {
        case .pending: .orange
        case .ready: .green
        case .failed: .red
        }
    }
}
