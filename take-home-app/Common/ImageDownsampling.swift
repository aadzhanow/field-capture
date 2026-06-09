//
//  ImageDownsampling.swift
//

import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Downsample-on-decode for *display* thumbnails. Decodes straight to a small
/// bitmap via ImageIO instead of decoding the full image and shrinking, so a
/// 25-photo pending grid never holds 25 full-resolution bitmaps in memory
/// (§4.3/§11). This is UI-only; the byte-targeting derivative pipeline (P3) is
/// a separate concern.
enum ImageDownsampling {
    /// Returns a `UIImage` whose long edge is at most `maxPixelSize`, decoded
    /// directly at that size. Never upscales. Returns `nil` if `data` can't be
    /// decoded as an image.
    static func thumbnail(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
