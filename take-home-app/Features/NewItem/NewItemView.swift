//
//  NewItemView.swift
//

import PhotosUI
import SwiftUI

struct NewItemView: View {
    @State private var vm: NewItemViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var isImporting = false

    init(diContainer: DIContainer) {
        vm = .init(
            itemRepository: diContainer.itemRepository,
            processingEngine: diContainer.processingEngine
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                photosSection
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await vm.save() } }
                        .disabled(!vm.canSave)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { id, data in
                    Task { await vm.addPhoto(id: id, data: data) }
                } onDelete: { id in
                    vm.removePhoto(id)
                }
            }
            .onChange(of: vm.didSave) { _, didSave in
                if didSave { dismiss() }
            }
            .disabled(vm.isSaving)
            .interactiveDismissDisabled(vm.isSaving)
            .overlay { savingOverlay }
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Title", text: $vm.title)
            TextField("Notes (optional)", text: $vm.notes, axis: .vertical)
                .lineLimit(1...4)
        } header: {
            Text("Details")
        } footer: {
            if vm.validationError == .titleEmpty {
                Text(ItemValidationError.titleEmpty.message)
                    .foregroundStyle(.red)
            }
        }
    }

    private var photosSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                PhotosPicker(
                    selection: $pickerItems,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if isImporting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Importing…").foregroundStyle(.secondary)
                }
            }

            if vm.pendingPhotos.isEmpty {
                Text("No photos yet. Capture from the camera or add from your library.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                PendingPhotoGrid(photos: vm.pendingPhotos) { id in
                    vm.removePhoto(id)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("^[\(vm.pendingPhotos.count) photo](inflect: true)")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if vm.validationError == .noPhotos {
                    Text(ItemValidationError.noPhotos.message)
                }
                if let saveError = vm.saveErrorMessage {
                    Text("Save failed: \(saveError)")
                }
            }
            .foregroundStyle(.red)
        }
        .listRowSeparator(.hidden)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPicked(items) }
        }
    }

    @ViewBuilder
    private var savingOverlay: some View {
        if vm.isSaving {
            ProgressView("Saving…")
                .padding(24)
                .background(.regularMaterial, in: .rect(cornerRadius: 16))
        }
    }

    private func importPicked(_ items: [PhotosPickerItem]) async {
        isImporting = true
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        await vm.addPhotos(datas)
        pickerItems = []
        isImporting = false
    }
}
