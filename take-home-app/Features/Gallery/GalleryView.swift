//
//  GalleryView.swift
//

import SwiftUI

struct GalleryView: View {
    @State private var vm: GalleryViewModel

    init(
        diContainer: DIContainer
    ) {
        vm = .init(itemRepository: diContainer.itemRepository)
    }

    var body: some View {
        NavigationStack {
            StateContainer(vm.state) { sections in
                GalleryList(sections: sections)
            } empty: {
                EmptyGalleryView()
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // P2: profile.
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") {
                        // P2: multi-select.
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CameraButton(action: {
                    
                })
                .padding(16)
            }
        }
        .task {
            vm.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedDebugItem") {
                await vm.debugInsertItem()
            }
            #endif
        }
    }
}

private struct GalleryList: View {
    let sections: [GallerySection]

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        GalleryRow(item: item)
                    }
                }
            }
        }
    }
}

private struct GalleryRow: View {
    let item: GalleryItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.quaternary, in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text("^[\(item.photoCount) photo](inflect: true) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyGalleryView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Items Yet", systemImage: "tray")
        } description: {
            Text("Captured items will appear here.")
        }
    }
}
