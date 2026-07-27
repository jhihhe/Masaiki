import XCTest
import CoreImage
@testable import MasaikiCore

final class MasaikiCoreTests: XCTestCase {

    func testBlurRegionEquality() {
        let a = BlurRegion(rect: CGRect(x: 0, y: 0, width: 10, height: 10), type: .mosaic, intensity: 0.5)
        let b = BlurRegion(id: a.id, rect: a.rect, type: a.type, intensity: a.intensity)
        XCTAssertEqual(a, b)
    }

    func testBlurTypeLocalization() {
        XCTAssertFalse(BlurType.mosaic.localizedName.isEmpty)
        XCTAssertFalse(BlurType.gaussian.localizedName.isEmpty)
    }

    func testApplyKeepsExtent() {
        // 100x100 red image
        let image = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let region = BlurRegion(rect: CGRect(x: 10, y: 10, width: 40, height: 40),
                                type: .mosaic, intensity: 0.5)
        let processed = ImageProcessingService.shared.apply(regions: [region], to: image)
        XCTAssertEqual(processed.extent.width, 100, accuracy: 0.01)
        XCTAssertEqual(processed.extent.height, 100, accuracy: 0.01)
    }

    func testEncodeDecodeRoundTrip() throws {
        let image = CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
        let data = try ImageIOService.shared.encode(image,
                                                    utType: "public.png",
                                                    properties: [:],
                                                    targetFileSize: nil)
        let decoded = try ImageIOService.shared.decode(data: data)
        XCTAssertEqual(decoded.ciImage.extent.width, 64, accuracy: 0.01)
    }
}
