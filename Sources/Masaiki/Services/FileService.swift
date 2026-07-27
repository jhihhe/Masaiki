import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import MasaikiCore

/// macOS file service: sandbox-aware. All user file access goes through
/// user-selected URLs (NSOpenPanel / NSSavePanel) which are automatically
/// granted temporary read/write permission via the `user-selected` entitlement.
final class FileService {
    static let shared = FileService()
    private init() {}

    // MARK: - Load

    func loadImage(from url: URL) throws -> ImageIOService.DecodedImage {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        return try ImageIOService.shared.decode(data: data)
    }

    // MARK: - Save (in place)

    /// Overwrite the user-selected file. Uses `FileManager.replaceItem` for atomicity.
    /// In App Sandbox, the destination `url` MUST be a user-selected URL (via NSOpenPanel
    /// or resolved from a security-scoped bookmark).
    func save(_ ciImage: CIImage,
              over url: URL,
              originalFileSize: Int,
              originalProperties: [String: Any],
              utType: String) async throws -> Int {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data = try ImageIOService.shared.encode(
            ciImage,
            utType: utType,
            properties: originalProperties,
            targetFileSize: originalFileSize
        )

        // Write to a temp file in the caches directory (always writable in sandbox),
        // then atomically replace the destination.
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("masaiki-\(UUID().uuidString).tmp")
        try data.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        var resultingURL: NSURL?
        _ = try FileManager.default.replaceItem(
            at: url,
            withItemAt: tempURL,
            backupItemName: nil,
            options: [.usingNewMetadataOnly],
            resultingItemURL: &resultingURL
        )
        return data.count
    }

    // MARK: - Export copy

    /// Export a copy of the processed image to a user-chosen directory (NSSavePanel).
    /// Preferred flow under App Sandbox when the user did not originally choose the file.
    func exportCopy(_ ciImage: CIImage,
                    to url: URL,
                    utType: String,
                    properties: [String: Any]) throws -> Int {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data = try ImageIOService.shared.encode(
            ciImage,
            utType: utType,
            properties: properties,
            targetFileSize: nil
        )
        try data.write(to: url, options: .atomic)
        return data.count
    }

    enum FileError: Error, LocalizedError {
        case fileNotFound
        case notWritable

        var errorDescription: String? {
            switch self {
            case .fileNotFound: return NSLocalizedString("file.error.notfound", value: "找不到文件", comment: "")
            case .notWritable:  return NSLocalizedString("file.error.notwritable", value: "文件不可写", comment: "")
            }
        }
    }
}
