//
//  ProcessActionBar.swift
//

import SwiftUI

struct ProcessActionBar: View {
    let detail: ItemDetail
    let onProcess: () -> Void

    var body: some View {
        switch detail.processingStatus {
        case .done:
            Label("Processed", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

        case .processing:
            Button(action: {}) {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Processing…")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)

        case .ready:
            Button(action: onProcess) {
                Label("Process", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .failed:
            VStack(spacing: 6) {
                if let error = detail.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: onProcess) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

        case .notReady:
            VStack(spacing: 6) {
                Text(blockedReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: {}) {
                    Text(blockedTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
        }
    }

    private var blockedReason: String {
        switch detail.assetStatus {
        case .failed:
            "Some derivatives failed. They must succeed before this item can be processed."
        case .complete:
            "Waiting until eligible — \(detail.eligibleAt.formatted(date: .abbreviated, time: .shortened)). Use Debug ▸ Make Eligible to bypass the 8-hour wait."
        case .processing, .incomplete:
            "Derivatives are still being generated."
        }
    }

    private var blockedTitle: String {
        switch detail.assetStatus {
        case .failed:                  "Assets Failed"
        case .complete:                "Waiting Until Eligible"
        case .processing, .incomplete: "Assets Processing"
        }
    }
}
