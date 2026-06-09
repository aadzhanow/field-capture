//
//  PendingPhotoGrid.swift
//

import SwiftUI

struct PendingPhotoGrid: View {
    let photos: [PendingPhoto]
    let onRemove: (PendingPhoto.ID) -> Void

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(photos) { photo in
                Image(uiImage: photo.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            onRemove(photo.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.55))
                        }
                        // Isolate the tap target so a row/section tap can't trigger removal.
                        .buttonStyle(.borderless)
                        .padding(4)
                    }
                    .accessibilityLabel("Photo")
            }
        }
    }
}
