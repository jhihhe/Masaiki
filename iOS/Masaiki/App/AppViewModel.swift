import Foundation
import UIKit
import SwiftUI
import Combine
import UniformTypeIdentifiers
import PhotosUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var selectedItemID: UUID?
    @Published var currentBlurType: BlurType = .gaussian
    @Published var currentIntensity: Double = 1.0
    @Published var lastError: String?

    var selectedItem: ImageItem? { items.first { $0.id == selectedItemID } }

    // MARK: - Import from PhotosPicker

    func importPickedItems(_ pickerItems: [PhotosPickerItem]) async {
        for pickerItem in pickerItems {
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else { continue }
                let decoded = try ImageIOService.shared.decode(data: data)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("masaiki-\(UUID().uuidString).\(fileExtension(for: decoded.utType))")
                try data.write(to: tempURL)
                let item = ImageItem(
                    url: tempURL,
                    originalImage: decoded.ciImage,
                    originalFileSize: decoded.fileSize,
                    originalProperties: decoded.properties,
                    originalUTType: decoded.utType
                )
                items.append(item)
                selectedItemID = item.id
                await detectFacesAsync(for: item)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Face detection

    func autoDetectFaces(for item: ImageItem) {
        Task { await detectFacesAsync(for: item) }
    }

    private func detectFacesAsync(for item: ImageItem) async {
        guard !item.isProcessing else { return }
        item.isProcessing = true
        item.errorMessage = nil
        do {
            let faces = try await FaceDetectionService.shared.detectFaces(in: item.originalImage)
            for face in faces {
                let expanded = face.insetBy(dx: -face.width * 0.1, dy: -face.height * 0.1)
                item.regions.append(BlurRegion(rect: expanded, type: currentBlurType, intensity: currentIntensity))
            }
            item.isProcessing = false
        } catch {
            item.errorMessage = String(format: NSLocalizedString("face.detect.failed", value: "人脸识别失败: %@", comment: ""), error.localizedDescription)
            item.isProcessing = false
        }
    }

    // MARK: - Export

    /// Returns a temp file URL of the exported image, suitable for UIActivityViewController or saving to Photos.
    func exportProcessed(item: ImageItem) throws -> URL {
        let data = try ImageIOService.shared.encode(
            item.processedImage,
            utType: item.originalUTType,
            properties: item.originalProperties,
            targetFileSize: item.originalFileSize
        )
        let ext = fileExtension(for: item.originalUTType)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("masaiki-out-\(UUID().uuidString).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Save processed image back to the user's photo library.
    /// Requires NSPhotoLibraryAddUsageDescription in Info.plist.
    func saveToPhotos(item: ImageItem) async throws {
        let data = try ImageIOService.shared.encode(
            item.processedImage,
            utType: item.originalUTType,
            properties: item.originalProperties,
            targetFileSize: item.originalFileSize
        )
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCreationRequest.forAsset()
            req.addResource(with: .photo, data: data, options: nil)
        }
    }

    // MARK: - Region ops

    func removeRegion(_ region: BlurRegion, from item: ImageItem) {
        item.regions.removeAll { $0.id == region.id }
    }

    func clearRegions(for item: ImageItem) {
        item.regions.removeAll()
    }

    func removeItem(_ item: ImageItem) {
        items.removeAll { $0.id == item.id }
        if selectedItemID == item.id { selectedItemID = items.first?.id }
    }

    // MARK: - Helpers

    private func fileExtension(for utType: String) -> String {
        switch utType {
        case UTType.png.identifier:  return "png"
        case UTType.heic.identifier: return "heic"
        case UTType.tiff.identifier: return "tiff"
        default:                     return "jpg"
        }
    }
}
