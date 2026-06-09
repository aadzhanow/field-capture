//
//  DebugView.swift
//

import SwiftUI

/// Test controls (§3): exercise failure, retry, and the 8-hour eligibility rule
/// without waiting. Simulate-offline and force-fail drive the mock processing
/// service; "Make Eligible" back-dates an item past the 8h window.
struct DebugView: View {
    @State private var vm: DebugViewModel
    private let debugSettings: DebugSettings
    @Environment(\.dismiss) private var dismiss

    init(diContainer: DIContainer) {
        debugSettings = diContainer.debugSettings
        vm = .init(itemRepository: diContainer.itemRepository)
    }

    var body: some View {
        @Bindable var settings = debugSettings
        NavigationStack {
            Form {
                Section {
                    Toggle("Simulate Offline", isOn: $settings.simulateOffline)
                    Toggle("Force Next Failure", isOn: $settings.forceNextFailure)
                } header: {
                    Text("Processing")
                } footer: {
                    Text("Simulate Offline fails every attempt. Force Next Failure is one-shot — the next attempt fails, then it clears.")
                }

                Section("Eligibility (8-hour rule)") {
                    if vm.items.isEmpty {
                        Text("No items yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.items) { item in
                            DebugItemRow(item: item) { vm.makeEligible(item.id) }
                        }
                    }
                }
            }
            .navigationTitle("Debug Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { vm.start() }
    }
}

private struct DebugItemRow: View {
    let item: GalleryItem
    let onMakeEligible: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.subheadline)
                StatusBadge.forGalleryItem(item)
            }
            Spacer()
            Button("Make Eligible", action: onMakeEligible)
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(item.processingStatus == .done)
        }
    }
}
