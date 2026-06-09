//
//  DerivativeGenerator.swift
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DerivativeError: Error, Equatable {
    case decodeFailed
    case cannotMeetByteCap
}

protocol DerivativeGenerator: Sendable {
    nonisolated func generate(from sourceData: Data, kind: DerivativeKind) throws -> Data
}

// Compress-to-fit: pixel-bounding alone doesn't bound encoded bytes, so at each
// candidate dimension we try JPEG quality high→low; if even the lowest quality
// exceeds the ≤700KB cap we step the dimension down and retry.
nonisolated struct DefaultDerivativeGenerator: DerivativeGenerator {
    private let qualitySteps: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
    private let dimensionStepFactor: CGFloat = 0.8
    private let minLongEdge: CGFloat = 64

    func generate(from sourceData: Data, kind: DerivativeKind) throws -> Data {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, options) else {
            throw DerivativeError.decodeFailed
        }

        var targetEdge = CGFloat(kind.maxLongEdge)
        if let sourceLongEdge = Self.sourceLongEdge(source) {
            targetEdge = min(targetEdge, sourceLongEdge)
        }

        while targetEdge >= minLongEdge {
            guard let image = Self.downsample(source, maxPixelSize: targetEdge) else {
                throw DerivativeError.decodeFailed
            }
            if let data = encodeFitting(image) {
                return data
            }
            let next = (targetEdge * dimensionStepFactor).rounded(.down)
            if next >= targetEdge { break }
            targetEdge = next
        }
        throw DerivativeError.cannotMeetByteCap
    }

    private func encodeFitting(_ image: CGImage) -> Data? {
        for quality in qualitySteps {
            guard let data = Self.encodeJPEG(image, quality: quality) else { continue }
            if data.count <= Constants.maxDerivativeBytes {
                return data
            }
        }
        return nil
    }

    private static func sourceLongEdge(_ source: CGImageSource) -> CGFloat? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue
        else {
            return nil
        }
        return CGFloat(max(width, height))
    }

    private static func downsample(_ source: CGImageSource, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // Encodes CGImage only (no source properties dict) — strips EXIF/GPS metadata.
    private static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
