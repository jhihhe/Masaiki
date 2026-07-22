import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var selectedItemID: UUID?
    @Published var currentBlurType: BlurType = .gaussian
    @Published var currentIntensity: Double = 1.0
    @Published var saveResult: SaveResult?

    var selectedItem: ImageItem? {
        items.first { $0.id == selectedItemID }
    }

    struct SaveResult: Identifiable {
        let id = UUID()
        let saved: Int
        let skipped: Int
    }

    func importImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff, .image]

        guard panel.runModal() == .OK else { return }
        handleDroppedURLs(panel.urls)
    }

    func handleDroppedURLs(_ urls: [URL]) {
        var imageURLs: [URL] = []
        let allowedExtensions = Set(["jpg", "jpeg", "png", "heic", "tiff", "tif", "bmp", "gif"])

        for url in urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        if allowedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            imageURLs.append(fileURL)
                        }
                    }
                }
            } else {
                if allowedExtensions.contains(url.pathExtension.lowercased()) {
                    imageURLs.append(url)
                }
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
                    print("Failed to load \(url): \(error)")
                }
            }

            // Switch preview to the last newly imported image immediately
            if let latest = newItems.last {
                selectedItemID = latest.id
            }

            // Automatically detect faces for imported images sequentially to keep UI smooth
            for item in newItems {
                await detectFacesAsync(for: item)
            }
        }
    }

    func autoDetectFaces(for item: ImageItem) {
        Task {
            await detectFacesAsync(for: item)
        }
    }

    private func detectFacesAsync(for item: ImageItem) async {
        guard !item.isProcessing else { return }
        await MainActor.run {
            item.isProcessing = true
            item.errorMessage = nil
        }

        do {
            let faces = try await FaceDetectionService.shared.detectFaces(in: item.originalImage)
            await MainActor.run {
                for face in faces {
                    let expanded = face.insetBy(dx: -face.width * 0.1, dy: -face.height * 0.1)
                    item.regions.append(BlurRegion(
                        rect: expanded,
                        type: currentBlurType,
                        intensity: currentIntensity
                    ))
                }
                item.isProcessing = false
            }
        } catch {
            await MainActor.run {
                item.errorMessage = "人脸识别失败: \(error.localizedDescription)"
                item.isProcessing = false
            }
        }
    }

    func save(item: ImageItem) {
        guard !item.regions.isEmpty else { return }
        Task {
            await saveItemAsync(item)
        }
    }

    func saveAll() {
        Task {
            var saved = 0
            var skipped = 0
            for item in items {
                if item.regions.isEmpty {
                    skipped += 1
                    continue
                }
                if await saveItemAsync(item) {
                    saved += 1
                }
            }
            await MainActor.run {
                saveResult = SaveResult(saved: saved, skipped: skipped)
            }
        }
    }

    private func saveItemAsync(_ item: ImageItem) async -> Bool {
        guard !item.isProcessing else { return false }
        await MainActor.run {
            item.isProcessing = true
            item.errorMessage = nil
        }

        do {
            let newSize = try await FileService.shared.save(
                item.processedImage,
                over: item.url,
                originalFileSize: item.originalFileSize,
                originalProperties: item.originalProperties,
                utType: item.originalUTType
            )
            await MainActor.run {
                item.isProcessing = false
                let diff = abs(Double(newSize) / Double(item.originalFileSize) - 1.0)
                if diff > 0.05 {
                    item.errorMessage = "已保存，但文件大小差异 \(String(format: "%.1f", diff * 100))%"
                }
            }
            return true
        } catch {
            await MainActor.run {
                item.errorMessage = "保存失败: \(error.localizedDescription)"
                item.isProcessing = false
            }
            return false
        }
    }

    func removeRegion(_ region: BlurRegion, from item: ImageItem) {
        item.regions.removeAll { $0.id == region.id }
    }

    func clearRegions(for item: ImageItem) {
        item.regions.removeAll()
    }

    func removeItem(_ item: ImageItem) {
        items.removeAll { $0.id == item.id }
        if selectedItemID == item.id {
            selectedItemID = items.first?.id
        }
    }
}
