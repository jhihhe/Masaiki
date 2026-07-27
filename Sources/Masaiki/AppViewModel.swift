import Foundation
import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers
import MasaikiCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var selectedItemID: UUID?
    @Published var currentBlurType: BlurType = .gaussian
    @Published var currentIntensity: Double = 1.0
    @Published var saveResult: SaveResult?

    var selectedItem: ImageItem? { items.first { $0.id == selectedItemID } }

    struct SaveResult: Identifiable {
        let id = UUID()
        let saved: Int
        let skipped: Int
    }

    // MARK: - Import (sandbox-safe: user-selected URLs)

    func importImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .image]
        panel.message = NSLocalizedString("import.message", value: "选择图片或包含图片的文件夹", comment: "")

        guard panel.runModal() == .OK else { return }
        handleDroppedURLs(panel.urls)
    }

    func handleDroppedURLs(_ urls: [URL]) {
        var imageURLs: [URL] = []
        let allowed = Set(["jpg", "jpeg", "png", "heic", "tiff", "tif", "bmp", "gif"])

        for url in urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if allowed.contains(fileURL.pathExtension.lowercased()) {
                            imageURLs.append(fileURL)
                        }
                    }
                }
            } else if allowed.contains(url.pathExtension.lowercased()) {
                imageURLs.append(url)
            }
        }

        loadImages(from: imageURLs)
    }

    func loadImages(from urls: [URL]) {
        Task {
            var newItems: [ImageItem] = []
            for url in urls {
                do {
                    let loaded = try FileService.shared.loadImage(from: url)
                    let item = ImageItem(
                        url: url,
                        originalImage: loaded.ciImage,
                        originalFileSize: loaded.fileSize,
                        originalProperties: loaded.properties,
                        originalUTType: loaded.utType
                    )
                    items.append(item)
                    newItems.append(item)
                } catch {
                    NSLog("Failed to load %@: %@", url.path, "\(error)")
                }
            }
            if let latest = newItems.last { selectedItemID = latest.id }
            for item in newItems { await detectFacesAsync(for: item) }
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

    // MARK: - Save

    func save(item: ImageItem) {
        guard !item.regions.isEmpty else { return }
        Task { _ = await saveItemAsync(item) }
    }

    func saveAll() {
        Task {
            var saved = 0, skipped = 0
            for item in items {
                if item.regions.isEmpty { skipped += 1; continue }
                if await saveItemAsync(item) { saved += 1 }
            }
            saveResult = SaveResult(saved: saved, skipped: skipped)
        }
    }

    /// Export the currently selected item to a user-picked location.
    /// This is the safer flow under App Sandbox when the user did not import
    /// the file via the app's picker in this session.
    func exportSelected() {
        guard let item = selectedItem else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = item.url.lastPathComponent
        if let type = UTType(item.originalUTType) {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        do {
            _ = try FileService.shared.exportCopy(
                item.processedImage,
                to: dest,
                utType: item.originalUTType,
                properties: item.originalProperties
            )
        } catch {
            item.errorMessage = String(format: NSLocalizedString("export.failed", value: "导出失败: %@", comment: ""), error.localizedDescription)
        }
    }

    private func saveItemAsync(_ item: ImageItem) async -> Bool {
        guard !item.isProcessing else { return false }
        item.isProcessing = true
        item.errorMessage = nil
        do {
            let newSize = try await FileService.shared.save(
                item.processedImage,
                over: item.url,
                originalFileSize: item.originalFileSize,
                originalProperties: item.originalProperties,
                utType: item.originalUTType
            )
            item.isProcessing = false
            let diff = abs(Double(newSize) / Double(item.originalFileSize) - 1.0)
            if diff > 0.05 {
                item.errorMessage = String(format: NSLocalizedString("save.size.diff", value: "已保存，但文件大小差异 %.1f%%", comment: ""), diff * 100)
            }
            return true
        } catch {
            item.errorMessage = String(format: NSLocalizedString("save.failed", value: "保存失败: %@", comment: ""), error.localizedDescription)
            item.isProcessing = false
            return false
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
}
