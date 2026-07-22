import Foundation
import AppKit
import CoreImage

final class ImageItem: ObservableObject, Identifiable {
    let id: UUID
    let url: URL
    let originalFileSize: Int
    let originalImage: CIImage
    let originalProperties: [String: Any]
    let originalUTType: String

    @Published var regions: [BlurRegion] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    init(url: URL, originalImage: CIImage, originalFileSize: Int, originalProperties: [String: Any], originalUTType: String) {
        self.id = UUID()
        self.url = url
        self.originalImage = originalImage
        self.originalFileSize = originalFileSize
        self.originalProperties = originalProperties
        self.originalUTType = originalUTType
    }

    var displayName: String {
        url.lastPathComponent
    }

    var processedImage: CIImage {
        ImageProcessingService.shared.apply(regions: regions, to: originalImage)
    }
}
