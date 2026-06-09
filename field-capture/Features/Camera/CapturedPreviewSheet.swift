//
//  CapturedPreviewSheet.swift
//

import SwiftUI
import UIKit

struct CapturedPreviewSheet: View {
    let photos: [SessionPhoto]
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?

    private var selected: SessionPhoto? {
        photos.first { $0.id == selectedID } ?? photos.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                mainImage
                strip
                Spacer(minLength: 0)
            }
            .padding()
            .safeAreaInset(edge: .bottom) { deleteBar }
            .navigationTitle("^[\(photos.count) photo](inflect: true)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if selectedID == nil { selectedID = photos.first?.id }
        }
    }

    @ViewBuilder
    private var deleteBar: some View {
        if let id = selected?.id {
            HStack {
                Button(role: .destructive) { delete(id) } label: {
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                        .glassEffectIfAvailable(in: .circle)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var mainImage: some View {
        CapturedImageView(id: selected?.id, data: selected?.data)
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .padding(12)
            .background(Color(.systemGray6), in: .rect(cornerRadius: 16))
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        thumbnail(photo).id(photo.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func thumbnail(_ photo: SessionPhoto) -> some View {
        Group {
            if let image = photo.thumbnail {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(.rect(cornerRadius: 8))
        .padding(2)
        .background(photo.id == selectedID ? Color.accentColor : .clear, in: .rect(cornerRadius: 10))
        .onTapGesture { selectedID = photo.id }
    }

    private func delete(_ id: String) {
        if selectedID == id {
            selectedID = photos.first { $0.id != id }?.id
        }
        onDelete(id)
    }
}

private struct CapturedImageView: View {
    let id: String?
    let data: Data?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: id) {
            let source = data
            image = await Task.detached {
                guard let source else { return nil }
                return ImageDownsampling.thumbnail(from: source, maxPixelSize: 1000)
            }.value
        }
    }
}
