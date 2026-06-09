//
//  ThumbnailStrip.swift
//

import SwiftUI

/// Horizontal strip of the item's photos, with a per-photo asset-status dot and
/// a tinted ring on the selected photo. Thumbnails upgrade live as derivatives
/// land (precedence `thumbnail → card → preview`).
struct ThumbnailStrip: View {
    let photos: [DetailPhoto]
    let fileStorage: FileStorage
    @Binding var selectedID: DetailPhoto.ID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    ThumbnailCell(
                        photo: photo,
                        fileStorage: fileStorage,
                        isSelected: photo.id == selectedID
                    )
                    .onTapGesture { selectedID = photo.id }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct ThumbnailCell: View {
    let photo: DetailPhoto
    let fileStorage: FileStorage
    let isSelected: Bool

    var body: some View {
        AsyncImageView(
            relativePaths: photo.thumbnailImagePaths,
            fileStorage: fileStorage,
            targetPixelSize: 160
        )
        .frame(width: 56, height: 56)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .bottomTrailing) { statusDot.padding(3) }
        .padding(2)
        .background(isSelected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 10))
    }

    private var statusDot: some View {
        Color.clear
            .frame(width: 10, height: 10)
            .background(dotColor, in: .circle)
            .padding(1.5)
            .background(.white, in: .circle)
    }

    private var dotColor: Color {
        switch photo.assetStatus {
        case .complete: .green
        case .processing: .orange
        case .incomplete: .gray
        case .failed: .red
        }
    }
}
