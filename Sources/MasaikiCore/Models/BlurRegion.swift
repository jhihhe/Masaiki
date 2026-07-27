import Foundation
import CoreGraphics

public enum BlurType: String, CaseIterable, Identifiable, Sendable, Codable {
    case mosaic
    case gaussian

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .mosaic:   return NSLocalizedString("blur.type.mosaic", value: "马赛克", comment: "Mosaic blur")
        case .gaussian: return NSLocalizedString("blur.type.gaussian", value: "高斯模糊", comment: "Gaussian blur")
        }
    }
}

public struct BlurRegion: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public var rect: CGRect
    public var type: BlurType
    public var intensity: Double

    public init(id: UUID = UUID(), rect: CGRect, type: BlurType, intensity: Double) {
        self.id = id
        self.rect = rect
        self.type = type
        self.intensity = intensity
    }

    public static func == (lhs: BlurRegion, rhs: BlurRegion) -> Bool {
        lhs.id == rhs.id &&
        lhs.rect == rhs.rect &&
        lhs.type == rhs.type &&
        lhs.intensity == rhs.intensity
    }
}
