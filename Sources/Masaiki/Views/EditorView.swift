import SwiftUI

struct EditorView: View {
    @ObservedObject var item: ImageItem
    @ObservedObject var viewModel: AppViewModel

    @State private var containerSize: CGSize = .zero
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    private var imageSize: CGSize {
        item.originalImage.extent.size
    }

    private var displayScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return 1
        }
        return min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    }

    private var displayOrigin: CGPoint {
        let scaled = CGSize(width: imageSize.width * displayScale, height: imageSize.height * displayScale)
        let x = (containerSize.width - scaled.width) / 2
        let y = (containerSize.height - scaled.height) / 2
        return CGPoint(x: x, y: y)
    }

    private var displayFrame: CGRect {
        CGRect(origin: displayOrigin, size: CGSize(width: imageSize.width * displayScale, height: imageSize.height * displayScale))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.06)

                if let nsImage = ImageProcessingService.shared.render(item.processedImage) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                }

                // Existing regions overlay
                ForEach(item.regions) { region in
                    let rect = imageRectToViewRect(region.rect)
                    ZStack(alignment: .topTrailing) {
                        Rectangle()
                            .stroke(region.type == .mosaic ? Color.yellow : Color.cyan, lineWidth: 2)
                            .background((region.type == .mosaic ? Color.yellow : Color.cyan).opacity(0.04))

                        Button(action: { viewModel.removeRegion(region, from: item) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 8, y: -8)
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                }

                // Dragging preview
                if let start = dragStart, let current = dragCurrent {
                    let rect = CGRect(origin: start, size: CGSize(width: current.x - start.x, height: current.y - start.y)).standardized
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.15))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if dragStart == nil {
                            dragStart = value.startLocation
                        }
                        dragCurrent = value.location
                    }
                    .onEnded { value in
                        defer {
                            dragStart = nil
                            dragCurrent = nil
                        }
                        guard let start = dragStart else { return }
                        let viewRect = CGRect(origin: start, size: CGSize(width: value.location.x - start.x, height: value.location.y - start.y)).standardized
                        let imageRect = viewRectToImageRect(viewRect)
                        guard imageRect.width > 8, imageRect.height > 8 else { return }
                        let clamped = imageRect.intersection(CGRect(origin: .zero, size: imageSize))
                        guard !clamped.isEmpty else { return }
                        item.regions.append(BlurRegion(
                            rect: clamped,
                            type: viewModel.currentBlurType,
                            intensity: viewModel.currentIntensity
                        ))
                    }
            )
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
            }
            .onAppear {
                containerSize = geometry.size
            }
        }
    }

    private func viewRectToImageRect(_ rect: CGRect) -> CGRect {
        let originX = (rect.origin.x - displayOrigin.x) / displayScale
        let originY = (rect.origin.y - displayOrigin.y) / displayScale
        let width = rect.width / displayScale
        let height = rect.height / displayScale
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private func imageRectToViewRect(_ rect: CGRect) -> CGRect {
        let originX = rect.origin.x * displayScale + displayOrigin.x
        let originY = rect.origin.y * displayScale + displayOrigin.y
        let width = rect.width * displayScale
        let height = rect.height * displayScale
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
