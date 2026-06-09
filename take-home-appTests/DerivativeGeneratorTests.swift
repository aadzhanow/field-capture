//
//  DerivativeGeneratorTests.swift
//

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import take_home_app

/// The ≤700,000-byte cap is the single most failure-prone requirement (§5/§11),
/// so it gets a dedicated test rather than relying on manual inspection. The hard
/// case is a large, **noisy** source: random pixels barely compress, so a 1920px
/// JPEG routinely exceeds the cap at high quality and forces the compress-to-fit
/// loop (and, if needed, the dimension step-down) to do real work.
final class DerivativeGeneratorTests: XCTestCase {
    private let generator = DefaultDerivativeGenerator()

    func testEveryDerivativeKindStaysWithinByteCap() throws {
        let source = try Self.makeNoisyJPEG(width: 4000, height: 3000)
        for kind in DerivativeKind.allCases {
            let data = try generator.generate(from: source, kind: kind)
            XCTAssertFalse(data.isEmpty, "\(kind) produced empty data")
            XCTAssertLessThanOrEqual(
                data.count,
                Constants.maxDerivativeBytes,
                "\(kind) derivative was \(data.count) bytes, over the 700KB cap"
            )
        }
    }

    func testDoesNotUpscaleSmallSource() throws {
        // A source smaller than a kind's max long edge must not be upscaled.
        let source = try Self.makeNoisyJPEG(width: 100, height: 80)
        let data = try generator.generate(from: source, kind: .processing) // 1920px max
        let longEdge = try Self.longEdge(of: data)
        XCTAssertLessThanOrEqual(longEdge, 100, "Derivative was upscaled beyond the source's long edge")
    }

    func testInvalidDataThrows() {
        let notAnImage = Data("definitely not an image".utf8)
        XCTAssertThrowsError(try generator.generate(from: notAnImage, kind: .thumbnail))
    }

    // MARK: - Helpers

    /// A JPEG of random-noise pixels at maximum quality — a deliberately
    /// incompressible, large source.
    private static func makeNoisyJPEG(width: Int, height: Int) throws -> Data {
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        var rng = SystemRandomNumberGenerator()
        for i in pixels.indices { pixels[i] = UInt8.random(in: 0...255, using: &rng) }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            throw TestError.imageCreationFailed
        }

        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            out, UTType.jpeg.identifier as CFString, 1, nil
        ) else {
            throw TestError.imageCreationFailed
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw TestError.imageCreationFailed }
        return out as Data
    }

    private static func longEdge(of jpeg: Data) throws -> Int {
        guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            throw TestError.imageCreationFailed
        }
        return max(width, height)
    }

    private enum TestError: Error { case imageCreationFailed }
}
