//
//  GalleryView.swift
//

import SwiftUI

struct GalleryView: View {
    private let diContainer: DIContainer
    @State private var vm: GalleryViewModel
    @State private var showingNewItem = false

    init(
        diContainer: DIContainer
    ) {
        self.diContainer = diContainer
        vm = .init(itemRepository: diContainer.itemRepository)
    }

    var body: some View {
        NavigationStack {
            StateContainer(vm.state) { sections in
                GalleryList(sections: sections, diContainer: diContainer)
            } empty: {
                EmptyGalleryView()
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // P5: profile.
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") {
                        // Later: multi-select.
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                CameraButton(action: { showingNewItem = true })
                    .padding(16)
            }
        }
        .sheet(isPresented: $showingNewItem) {
            NewItemView(diContainer: diContainer)
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
    let diContainer: DIContainer

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        NavigationLink {
                            ItemDetailView(diContainer: diContainer, itemID: item.id)
                        } label: {
                            GalleryCard(item: item, fileStorage: diContainer.fileStorage)
                        }
                    }
                }
            }
        }
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
