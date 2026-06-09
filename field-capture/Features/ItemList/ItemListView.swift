//
//  ItemListView.swift
//

import SwiftUI

struct ItemListView: View {
    private let diContainer: DIContainer
    @State private var vm: ItemListViewModel
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
                ItemListContent(
                    sections: sections,
                    diContainer: diContainer,
                    onDelete: { vm.deleteItem($0) }
                )
            } empty: {
                EmptyItemListView()
            } loading: {
                ItemListSkeleton()
            }
            .navigationTitle("Item List")
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

private struct ItemListContent: View {
    let sections: [ItemListSection]
    let diContainer: DIContainer
    let onDelete: (String) -> Void

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        NavigationLink(value: item.id) {
                            ItemCard(item: item, fileStorage: diContainer.fileStorage)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EmptyItemListView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Items Yet", systemImage: "tray")
        } description: {
            Text("Captured items will appear here.")
        }
    }
}
