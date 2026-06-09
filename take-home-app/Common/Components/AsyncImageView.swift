//
//  AsyncImageView.swift
//

import SwiftUI
import UIKit

/// Loads a derivative image file by **relative path**, trying each path in
/// precedence order (`card → thumbnail → placeholder`) and showing a placeholder
/// until one resolves. Decoding happens off the main actor and downsamples to the
/// requested size, so a scrolling gallery never blocks on full-size decodes.
///
/// Driven by `ValueObservation`, so when a derivative lands the path list changes,
/// the `.task(id:)` re-fires, and the card upgrades live from placeholder → image.
struct AsyncImageView: View {
    let relativePaths: [String]
    let fileStorage: FileStorage
    /// Max long edge (in pixels) to decode to.
    var targetPixelSize: CGFloat = 400
    /// `.fill` crops to fill (default); `.fit` letterboxes to show the whole image.
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
        // Clip the aspect-fill overflow to our own bounds, so an image never
        // pushes the surrounding layout wider than the screen.
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
