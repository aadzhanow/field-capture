//
//  DerivativeGenerator.swift
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DerivativeError: Error, Equatable {
    case decodeFailed
    /// Even the smallest dimension at the lowest quality exceeded the byte cap.
    case cannotMeetByteCap
}

/// Produces a single derivative image, bounded by the ≤700,000-byte hard cap (§5).
/// Pure data-in/data-out so it can be unit-tested without disk or a database.
protocol DerivativeGenerator: Sendable {
    /// Returns a JPEG for `kind` derived from `sourceData`: downsampled to the
    /// kind's max long edge (never upscaling), metadata stripped, and compressed
    /// to fit `Constants.maxDerivativeBytes`. Throws `DerivativeError` on failure.
    ///
    /// `nonisolated`: image work runs off the main actor in the pipeline.
    nonisolated func generate(from sourceData: Data, kind: DerivativeKind) throws -> Data
}

/// Bounding the pixel long edge does **not** bound encoded bytes — a noisy 1920px
/// JPEG routinely exceeds 700KB — so generation is *compress-to-fit*, not just
/// resize: at each candidate dimension we try JPEG quality high→low, and if even
/// the lowest quality is over the cap we step the dimension down and retry.
nonisolated struct DefaultDerivativeGenerator: DerivativeGenerator {
    /// JPEG qualities tried high→low at each candidate dimension.
    private let qualitySteps: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
    /// Dimension step-down factor when the lowest quality still exceeds the cap.
    private let dimensionStepFactor: CGFloat = 0.8
    /// Floor for the step-down so a pathological input can't shrink forever.
    private let minLongEdge: CGFloat = 64

    func generate(from sourceData: Data, kind: DerivativeKind) throws -> Data {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, options) else {
            throw DerivativeError.decodeFailed
        }

        // Never upscale: cap the target edge to the source's actual long edge.
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
            if next >= targetEdge { break } // no progress — bail rather than spin
            targetEdge = next
        }
        throw DerivativeError.cannotMeetByteCap
    }

    /// Encodes the image at decreasing quality, returning the first result within
    /// the byte cap, or nil if even the lowest quality is too large at this size.
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

    /// Downsamples on decode — ImageIO renders straight to the target size rather
    /// than decoding the full bitmap, keeping peak memory low for 25-photo runs.
    private static func downsample(_ source: CGImageSource, maxPixelSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Re-encodes only the CGImage (no source property dictionary), so EXIF/GPS
    /// and other metadata are stripped from the output.
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
