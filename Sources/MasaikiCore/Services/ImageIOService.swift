import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Cross-platform decoding / encoding using ImageIO only.
/// Keeps macOS/iOS layers thin and avoids AppKit/UIKit specific APIs.
public final class ImageIOService: @unchecked Sendable {
    public static let shared = ImageIOService()

    private let context: CIContext

    private init() {
        self.context = CIContext(options: [
            .cacheIntermediates: false,
            .name: "MasaikiIOContext"
        ])
    }

    public struct DecodedImage: Sendable {
        public let ciImage: CIImage
        public let fileSize: Int
        public let properties: [String: Any]
        public let utType: String
    }

    public enum IOError: Error, LocalizedError {
        case unsupportedFormat
        case renderFailed
        case encodeFailed

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return NSLocalizedString("io.error.format", value: "不支持的图片格式", comment: "")
            case .renderFailed:      return NSLocalizedString("io.error.render", value: "图像渲染失败",   comment: "")
            case .encodeFailed:      return NSLocalizedString("io.error.encode", value: "图像编码失败",   comment: "")
            }
        }
    }

    // MARK: - Decode

    public func decode(data: Data) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw IOError.unsupportedFormat
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let sourceType = (CGImageSourceGetType(source) as String?) ?? UTType.jpeg.identifier

        return DecodedImage(
            ciImage: CIImage(cgImage: cgImage),
            fileSize: data.count,
            properties: properties,
            utType: sourceType
        )
    }

    // MARK: - Encode

    /// Encode a CIImage back to Data. If JPEG and a target size is provided, tries to match the target size.
    public func encode(_ ciImage: CIImage,
                       utType: String,
                       properties: [String: Any],
                       targetFileSize: Int?) throws -> Data {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw IOError.renderFailed
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, utType as CFString, 1, nil) else {
            throw IOError.encodeFailed
        }

        var mutableProperties = properties
        if utType == UTType.jpeg.identifier, let target = targetFileSize {
            let quality = findJPEGQuality(for: cgImage, utType: utType, properties: properties, targetSize: target)
            mutableProperties[kCGImageDestinationLossyCompressionQuality as String] = quality
        }

        CGImageDestinationAddImage(destination, cgImage, mutableProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw IOError.encodeFailed
        }
        return data as Data
    }

    private func findJPEGQuality(for cgImage: CGImage, utType: String, properties: [String: Any], targetSize: Int) -> Double {
        var low = 0.5, high = 1.0
        var bestQuality = 0.92
        var bestDiff = Double.infinity

        for _ in 0..<8 {
            let mid = (low + high) / 2
            guard let size = try? encodedSize(for: cgImage, utType: utType, properties: properties, quality: mid) else { break }
            let ratio = Double(size) / Double(targetSize)
            let diff = abs(ratio - 1.0)
            if diff < bestDiff { bestDiff = diff; bestQuality = mid }
            if ratio < 0.95      { low  = mid }
            else if ratio > 1.05 { high = mid }
            else                 { return mid }
        }
        return bestQuality
    }

    private func encodedSize(for cgImage: CGImage, utType: String, properties: [String: Any], quality: Double) throws -> Int {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, utType as CFString, 1, nil) else {
            throw IOError.encodeFailed
        }
        var props = properties
        props[kCGImageDestinationLossyCompressionQuality as String] = quality
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw IOError.encodeFailed }
        return data.length
    }
}
