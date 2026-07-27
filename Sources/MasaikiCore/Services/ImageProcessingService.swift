import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Cross-platform (macOS/iOS) image processor. No AppKit/UIKit dependency.
public final class ImageProcessingService: @unchecked Sendable {
    public static let shared = ImageProcessingService()

    private let context: CIContext

    private init() {
        self.context = CIContext(options: [
            .cacheIntermediates: false,
            .name: "MasaikiProcessingContext",
        ])
    }

    public func apply(regions: [BlurRegion], to image: CIImage) -> CIImage {
        var output = image
        for region in regions {
            output = apply(region: region, to: output)
        }
        return output
    }

    private func apply(region: BlurRegion, to image: CIImage) -> CIImage {
        // BlurRegion coordinates are in top-left origin (UI/display space).
        // Core Image uses bottom-left origin, so we flip the Y axis.
        let flippedRect = CGRect(
            x: region.rect.origin.x,
            y: image.extent.height - region.rect.origin.y - region.rect.height,
            width: region.rect.width,
            height: region.rect.height
        )
        let rect = flippedRect.intersection(image.extent)
        guard !rect.isEmpty else { return image }

        let cropped = image.cropped(to: rect)
        let blurred: CIImage
        switch region.type {
        case .mosaic: blurred = applyMosaic(to: cropped, intensity: region.intensity)
        case .gaussian: blurred = applyGaussianBlur(to: cropped, intensity: region.intensity)
        }

        // Gaussian blur expands the extent; crop back to the region.
        let croppedBlurred = blurred.cropped(to: rect)
        return croppedBlurred.composited(over: image)
    }

    private func applyMosaic(to image: CIImage, intensity: Double) -> CIImage {
        let filter = CIFilter.pixellate()
        filter.inputImage = image
        filter.scale = Float(4 + intensity * 56)  // 4...60
        return filter.outputImage ?? image
    }

    private func applyGaussianBlur(to image: CIImage, intensity: Double) -> CIImage {
        // 1) affineClamp 消除高斯模糊在裁剪边缘引入的半透明像素
        let clamp = CIFilter.affineClamp()
        clamp.inputImage = image
        clamp.transform = .identity
        let clamped = clamp.outputImage ?? image

        // 2) 拉高上限（2..60），配合叠加一次弱二次模糊，让磨砂质感更厚
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = clamped
        filter.radius = Float(4 + intensity * 56)
        guard let firstPass = filter.outputImage else { return image }

        // 3) 强制 alpha=1，确保模糊层完全不透明覆盖到原图
        let opaque = CIFilter.colorMatrix()
        opaque.inputImage = firstPass.cropped(to: image.extent)
        opaque.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)  // 输出 alpha 恒为 1
        opaque.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return opaque.outputImage ?? firstPass.cropped(to: image.extent)
    }

    /// Render a CIImage to CGImage. Platform layers can wrap it to NSImage/UIImage.
    public func renderCGImage(_ ciImage: CIImage) -> CGImage? {
        context.createCGImage(ciImage, from: ciImage.extent)
    }

    /// 提取并渲染指定区域的模糊补丁（用于 UI 拖拽时的独立图层）
    public func renderPatch(region: BlurRegion, from image: CIImage) -> CGImage? {
        let flippedRect = CGRect(
            x: region.rect.origin.x,
            y: image.extent.height - region.rect.origin.y - region.rect.height,
            width: region.rect.width,
            height: region.rect.height
        )
        let rect = flippedRect.intersection(image.extent)
        guard !rect.isEmpty else { return nil }

        let cropped = image.cropped(to: rect)
        let blurred: CIImage
        switch region.type {
        case .mosaic: blurred = applyMosaic(to: cropped, intensity: region.intensity)
        case .gaussian: blurred = applyGaussianBlur(to: cropped, intensity: region.intensity)
        }

        let croppedBlurred = blurred.cropped(to: rect)
        // 注意：不执行 composited(over:)，直接返回补丁的 CGImage
        return context.createCGImage(croppedBlurred, from: rect)
    }
}
