//
//  GalleryView.swift
//

import SwiftUI

struct GalleryView: View {
    private let diContainer: DIContainer
    @State private var vm: GalleryViewModel
    @State private var showingNewItem = false
    @State private var showingDebug = false
    @Environment(\.scenePhase) private var scenePhase

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
            .navigationDestination(for: String.self) { itemID in
                ItemDetailView(diContainer: diContainer, itemID: itemID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingDebug = true
                    } label: {
                        Image(systemName: "hammer")
                            .font(.system(size: 14))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewItem) {
            NewItemView(diContainer: diContainer)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingDebug) {
            DebugView(diContainer: diContainer)
        }
        .task {
            vm.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedDebugItem") {
                await vm.debugInsertItem()
            }
            #endif
        }
        .task {
            while !Task.isCancelled {
                await vm.refreshEligibility()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.refreshEligibility() } }
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
                        NavigationLink(value: item.id) {
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
