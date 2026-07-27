import Foundation
import Vision
import CoreImage

public final class FaceDetectionService: @unchecked Sendable {
    public static let shared = FaceDetectionService()

    private init() {}

    /// Returns face rectangles in top-left-origin pixel coordinates matching the CIImage extent.
    public func detectFaces(in ciImage: CIImage) async throws -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else { return [] }

        let imageSize = ciImage.extent.size
        return results.map { observation in
            let boundingBox = observation.boundingBox
            let x = boundingBox.origin.x * imageSize.width
            let y = (1.0 - boundingBox.origin.y - boundingBox.height) * imageSize.height
            let width = boundingBox.width * imageSize.width
            let height = boundingBox.height * imageSize.height
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
}
