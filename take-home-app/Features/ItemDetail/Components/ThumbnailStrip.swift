//
//  ThumbnailStrip.swift
//

import SwiftUI

struct ThumbnailStrip: View {
    let photos: [DetailPhoto]
    let fileStorage: FileStorage
    @Binding var selectedID: DetailPhoto.ID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        ThumbnailCell(
                            photo: photo,
                            fileStorage: fileStorage,
                            isSelected: photo.id == selectedID
                        )
                        .id(photo.id)
                        .onTapGesture { selectedID = photo.id }
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
