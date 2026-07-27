import SwiftUI
import UIKit

struct EditorView: View {
    @ObservedObject var item: ImageItem
    @ObservedObject var viewModel: AppViewModel

    @State private var containerSize: CGSize = .zero
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var zoomScale: CGFloat = 1
    @State private var pinchBaseScale: CGFloat = 1

    private var imageSize: CGSize { item.originalImage.extent.size }
    private var baseDisplaySize: CGSize {
        CGSize(width: imageSize.width * displayScale, height: imageSize.height * displayScale)
    }
    private var canvasCenter: CGPoint {
        CGPoint(x: baseDisplaySize.width / 2, y: baseDisplaySize.height / 2)
    }

    private var displayScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else { return 1 }
        return min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    }

    private var displayOrigin: CGPoint {
        let scaled = CGSize(width: imageSize.width * displayScale,
                            height: imageSize.height * displayScale)
        return CGPoint(x: (containerSize.width - scaled.width) / 2,
                       y: (containerSize.height - scaled.height) / 2)
    }

    private func renderUIImage(_ ciImage: CoreImage.CIImage) -> UIImage? {
        guard let cg = ImageProcessingService.shared.renderCGImage(ciImage) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)

                if let uiImage = renderUIImage(item.processedImage) {
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: baseDisplaySize.width, height: baseDisplaySize.height)

                        ForEach(item.regions) { region in
                            RegionOverlay(
                                region: region,
                                viewRect: imageRectToCanvasRect(region.rect),
                                onDelete: { viewModel.removeRegion(region, from: item) },
                                onMove: { delta in moveRegion(id: region.id, viewDelta: delta) }
                            )
                        }
                    }
                    .frame(width: baseDisplaySize.width, height: baseDisplaySize.height)
                    .scaleEffect(zoomScale, anchor: .center)
                    .position(x: displayOrigin.x + canvasCenter.x,
                              y: displayOrigin.y + canvasCenter.y)
                    .clipped()
                } else {
                    ProgressView()
                }

                if let s = dragStart, let c = dragCurrent {
                    let rect = CGRect(origin: s,
                                      size: CGSize(width: c.x - s.x, height: c.y - s.y)).standardized
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.15))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStart == nil { dragStart = value.startLocation }
                        dragCurrent = value.location
                    }
                    .onEnded { value in
                        defer {
                            dragStart = nil
                            dragCurrent = nil
                        }
                        guard let start = dragStart else { return }
                        let viewRect = CGRect(origin: start,
                                              size: CGSize(width: value.location.x - start.x,
                                                           height: value.location.y - start.y)).standardized
                        let imageRect = viewRectToImageRect(viewRect)
                        let clamped = imageRect.intersection(CGRect(origin: .zero, size: imageSize))
                        guard clamped.width > 8, clamped.height > 8 else { return }
                        item.regions.append(BlurRegion(rect: clamped,
                                                       type: viewModel.currentBlurType,
                                                       intensity: viewModel.currentIntensity))
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoomScale = min(max(pinchBaseScale * value, 1), 4)
                    }
                    .onEnded { value in
                        zoomScale = min(max(pinchBaseScale * value, 1), 4)
                        pinchBaseScale = zoomScale
                    }
            )
            .onChange(of: geometry.size) { newSize in containerSize = newSize }
            .onAppear {
                containerSize = geometry.size
                zoomScale = 1
                pinchBaseScale = 1
            }
        }
    }

    private func moveRegion(id: UUID, viewDelta: CGSize) {
        guard let idx = item.regions.firstIndex(where: { $0.id == id }) else { return }
        let d = CGSize(width: viewDelta.width / (displayScale * zoomScale),
                       height: viewDelta.height / (displayScale * zoomScale))
        var rect = item.regions[idx].rect
        rect.origin.x = max(0, min(rect.origin.x + d.width,  imageSize.width  - rect.width))
        rect.origin.y = max(0, min(rect.origin.y + d.height, imageSize.height - rect.height))
        item.regions[idx].rect = rect
    }

    private func viewRectToImageRect(_ r: CGRect) -> CGRect {
        let origin = CGPoint(
            x: canvasCenter.x + (r.origin.x - displayOrigin.x - canvasCenter.x) / zoomScale,
            y: canvasCenter.y + (r.origin.y - displayOrigin.y - canvasCenter.y) / zoomScale
        )
        let size = CGSize(width: r.width / zoomScale, height: r.height / zoomScale)
        return CGRect(x: origin.x / displayScale,
                      y: origin.y / displayScale,
                      width: size.width / displayScale,
                      height: size.height / displayScale)
    }

    private func imageRectToCanvasRect(_ r: CGRect) -> CGRect {
        CGRect(x: r.origin.x * displayScale,
               y: r.origin.y * displayScale,
               width: r.width * displayScale,
               height: r.height * displayScale)
    }
}

/// 拖动过程中仅更新 liveOffset，松手后再一次性提交到 model，保证渲染流畅。
private struct RegionOverlay: View {
    let region: BlurRegion
    let viewRect: CGRect
    let onDelete: () -> Void
    let onMove: (CGSize) -> Void

    @State private var liveOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        let color: Color = (region.type == .mosaic) ? .yellow : .cyan

        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(color.opacity(isDragging ? 0.25 : 0.15))
                .overlay(Rectangle().stroke(color, lineWidth: 2))
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            isDragging = true
                            liveOffset = value.translation
                        }
                        .onEnded { value in
                            onMove(value.translation)
                            liveOffset = .zero
                            isDragging = false
                        }
                )

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
                    .background(Color.white.opacity(0.9).clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .offset(x: 12, y: -12)
        }
        .frame(width: viewRect.width, height: viewRect.height)
        .position(x: viewRect.midX + liveOffset.width,
                  y: viewRect.midY + liveOffset.height)
    }
}
