import Foundation
import CoreGraphics

enum BlurType: String, CaseIterable, Identifiable {
    case mosaic = "马赛克"
    case gaussian = "高斯模糊"

    var id: String { rawValue }
}

struct BlurRegion: Identifiable, Equatable {
    let id: UUID
    var rect: CGRect
    var type: BlurType
    var intensity: Double

    init(id: UUID = UUID(), rect: CGRect, type: BlurType, intensity: Double) {
        self.id = id
        self.rect = rect
        self.type = type
        self.intensity = intensity
    }

    static func == (lhs: BlurRegion, rhs: BlurRegion) -> Bool {
        lhs.id == rhs.id &&
        lhs.rect == rhs.rect &&
        lhs.type == rhs.type &&
        lhs.intensity == rhs.intensity
    }
}
