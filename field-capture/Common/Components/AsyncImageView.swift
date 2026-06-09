//
//  AsyncImageView.swift
//

import SwiftUI
import UIKit

struct AsyncImageView: View {
    let relativePaths: [String]
    let fileStorage: FileStorage
    var targetPixelSize: CGFloat = 400
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: relativePaths.first) {
            await load(relativePaths)
        }
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }

    private func load(_ paths: [String]) async {
        let storage = fileStorage
        let pixelSize = targetPixelSize
        let resolved = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            for path in paths {
                guard let data = try? storage.read(path) else { continue }
                if let image = ImageDownsampling.thumbnail(from: data, maxPixelSize: pixelSize) {
                    return image
                }
            }
            return nil
        }.value

        guard !Task.isCancelled else { return }
        image = resolved
    }
}
