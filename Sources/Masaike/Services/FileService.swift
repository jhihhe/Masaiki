import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

final class FileService {
    static let shared = FileService()
    private let context = CIContext(options: [
        .cacheIntermediates: false,
        .name: "MasaikeSaveContext"
    ])

    private init() {}

    struct LoadedImage {
        let ciImage: CIImage
        let fileSize: Int
        let properties: [String: Any]
        let utType: String
    }

    func loadImage(from url: URL) throws -> LoadedImage {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw FileError.unsupportedFormat
        }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FileError.unsupportedFormat
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let utTypes = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
        let utType = utTypes.first ?? UTType.jpeg.identifier

        let ciImage = CIImage(cgImage: cgImage)
        return LoadedImage(
            ciImage: ciImage,
            fileSize: data.count,
            properties: properties,
            utType: utType
        )
    }

    func save(_ ciImage: CIImage, over url: URL, originalFileSize: Int, originalProperties: [String: Any], utType: String) async throws -> Int {
        let ext = url.pathExtension
        let backupURL = url.deletingPathExtension().appendingPathExtension("original_backup" + (ext.isEmpty ? "" : ".\(ext)"))

        // Create backup if not exists
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: url, to: backupURL)
        }

        let finalData = try encodeImage(
            ciImage,
            utType: utType,
            properties: originalProperties,
            targetFileSize: originalFileSize
        )

        try finalData.write(to: url, options: .atomic)
        return finalData.count
    }

    private func encodeImage(_ ciImage: CIImage, utType: String, properties: [String: Any], targetFileSize: Int) throws -> Data {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw FileError.renderFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, utType as CFString, 1, nil) else {
            throw FileError.unsupportedFormat
        }

        let isJPEG = utType == UTType.jpeg.identifier
        var mutableProperties = properties

        if isJPEG {
            let quality = findJPEGQuality(for: cgImage, utType: utType, properties: properties, targetSize: targetFileSize)
            mutableProperties[kCGImageDestinationLossyCompressionQuality as String] = quality
        }

        CGImageDestinationAddImage(destination, cgImage, mutableProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw FileError.saveFailed
        }

        return data as Data
    }

    private func findJPEGQuality(for cgImage: CGImage, utType: String, properties: [String: Any], targetSize: Int) -> Double {
        let minQuality: Double = 0.5
        let maxQuality: Double = 1.0
        let tolerance: Double = 0.05

        var low = minQuality
        var high = maxQuality
        var bestQuality = 0.92
        var bestDiff = Double.infinity

        for _ in 0..<8 {
            let mid = (low + high) / 2
            if let size = try? encodedSize(for: cgImage, utType: utType, properties: properties, quality: mid) {
                let ratio = Double(size) / Double(targetSize)
                let diff = abs(ratio - 1.0)
                if diff < bestDiff {
                    bestDiff = diff
                    bestQuality = mid
                }

                if ratio < 1.0 - tolerance {
                    low = mid
                } else if ratio > 1.0 + tolerance {
                    high = mid
                } else {
                    return mid
                }
            } else {
                break
            }
        }

        return bestQuality
    }

    private func encodedSize(for cgImage: CGImage, utType: String, properties: [String: Any], quality: Double) throws -> Int {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, utType as CFString, 1, nil) else {
            throw FileError.saveFailed
        }
        var props = properties
        props[kCGImageDestinationLossyCompressionQuality as String] = quality
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw FileError.saveFailed
        }
        return data.length
    }

    enum FileError: Error, LocalizedError {
        case fileNotFound
        case unsupportedFormat
        case renderFailed
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "找不到文件"
            case .unsupportedFormat: return "不支持的图片格式"
            case .renderFailed: return "图像渲染失败"
            case .saveFailed: return "文件保存失败"
            }
        }
    }
}
