import Foundation
import CoreImage
import Combine

/// Cross-platform image item used by the UI on macOS and iOS.
/// The `url` may be a security-scoped URL on macOS or a temp file URL on iOS.
public final class ImageItem: ObservableObject, Identifiable {
    public let id: UUID
    public let url: URL
    public let originalFileSize: Int
    public let originalImage: CIImage
    public let originalProperties: [String: Any]
    public let originalUTType: String

    @Published public var regions: [BlurRegion] = []
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?

    public init(url: URL,
                originalImage: CIImage,
                originalFileSize: Int,
                originalProperties: [String: Any],
                originalUTType: String) {
        self.id = UUID()
        self.url = url
        self.originalImage = originalImage
        self.originalFileSize = originalFileSize
        self.originalProperties = originalProperties
        self.originalUTType = originalUTType
    }

    public var displayName: String { url.lastPathComponent }

    public var processedImage: CIImage {
        ImageProcessingService.shared.apply(regions: regions, to: originalImage)
    }
}
