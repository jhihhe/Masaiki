import AppKit
import MasaikiCore
import SwiftUI

// #region debug-point A-D:drag-double-overlay
private let dragDebugSessionId = "drag-double-overlay"
private let dragDebugEnvPath = ".dbg/drag-double-overlay.env"
private let dragDebugRunId = "post-fix"

private func dragDebugConfig() -> (url: String, sessionId: String) {
    var url = "http://127.0.0.1:7777/event"
    var sessionId = dragDebugSessionId
    if let env = try? String(contentsOfFile: dragDebugEnvPath, encoding: .utf8) {
        for line in env.split(separator: "\n") {
            if line.hasPrefix("DEBUG_SERVER_URL=") {
                url = String(line.dropFirst("DEBUG_SERVER_URL=".count))
            } else if line.hasPrefix("DEBUG_SESSION_ID=") {
                sessionId = String(line.dropFirst("DEBUG_SESSION_ID=".count))
            }
        }
    }
    return (url, sessionId)
}

private func dragDebugReport(
    _ hypothesisId: String,
    _ message: String,
    data: [String: Any] = [:],
    location: String
) {
    let config = dragDebugConfig()
    guard let url = URL(string: config.url) else { return }
    guard JSONSerialization.isValidJSONObject(data) else { return }
    let payload: [String: Any] = [
        "sessionId": config.sessionId,
        "runId": dragDebugRunId,
        "hypothesisId": hypothesisId,
        "location": location,
        "msg": "[DEBUG] \(message)",
        "data": data,
        "ts": Int(Date().timeIntervalSince1970 * 1000),
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    URLSession.shared.dataTask(with: request).resume()
}
// #endregion

struct EditorView: View {
    @ObservedObject var item: ImageItem
    @ObservedObject var viewModel: AppViewModel

    @State private var containerSize: CGSize = .zero
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    /// 当前正在拖动的区域 ID。拖动期间该区域从底图渲染中临时移除，
    /// 只保留 overlay 框跟随鼠标，避免"底图斑块 + overlay 框"的双影闪烁。
    @State private var draggingRegionID: UUID?

    /// 纯净的原图底图缓存。不再每帧走全图 CoreImage 管线。
    @State private var backgroundNSImage: NSImage?

    private var imageSize: CGSize { item.originalImage.extent.size }

    private var displayScale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0,
            containerSize.width > 0, containerSize.height > 0
        else { return 1 }
        return min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    }

    private var displayOrigin: CGPoint {
        let scaled = CGSize(
            width: imageSize.width * displayScale, height: imageSize.height * displayScale)
        return CGPoint(
            x: (containerSize.width - scaled.width) / 2,
            y: (containerSize.height - scaled.height) / 2)
    }

    private func renderNSImage(_ ciImage: CoreImage.CIImage) -> NSImage? {
        guard let cg = ImageProcessingService.shared.renderCGImage(ciImage) else { return nil }
        return NSImage(cgImage: cg, size: ciImage.extent.size)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.06)

                if let nsImage = backgroundNSImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                }

                // 已有区域：每个区域自己负责渲染自己那块的模糊效果，底图永远是原图。
                ForEach(item.regions) { region in
                    RegionOverlay(
                        region: region,
                        originalImage: item.originalImage,
                        viewRect: imageRectToViewRect(region.rect),
                        displayScale: displayScale,
                        imageSize: imageSize,
                        onDelete: { viewModel.removeRegion(region, from: item) },
                        onMove: { delta in
                            moveRegion(id: region.id, viewDelta: delta)
                        }
                    )
                }

                // 新建区域预览
                if draggingRegionID == nil, let start = dragStart, let current = dragCurrent {
                    let rect = CGRect(
                        origin: start,
                        size: CGSize(
                            width: current.x - start.x,
                            height: current.y - start.y)
                    ).standardized
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.15))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
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
                        let viewRect = CGRect(
                            origin: start,
                            size: CGSize(
                                width: value.location.x - start.x,
                                height: value.location.y - start.y)
                        ).standardized
                        let imageRect = viewRectToImageRect(viewRect)
                        guard imageRect.width > 8, imageRect.height > 8 else { return }
                        let clamped = imageRect.intersection(CGRect(origin: .zero, size: imageSize))
                        guard !clamped.isEmpty else { return }
                        item.regions.append(
                            BlurRegion(
                                rect: clamped,
                                type: viewModel.currentBlurType,
                                intensity: viewModel.currentIntensity
                            ))
                    }
            )
            .onChange(of: geometry.size) { newSize in containerSize = newSize }
            .onAppear {
                containerSize = geometry.size
                loadBackground()
            }
            .onChange(of: item.id) { _ in
                loadBackground()
            }
        }
    }

    private func loadBackground() {
        let base = item.originalImage
        Task.detached(priority: .userInitiated) {
            guard let cg = ImageProcessingService.shared.renderCGImage(base) else { return }
            let ns = NSImage(cgImage: cg, size: base.extent.size)
            await MainActor.run {
                self.backgroundNSImage = ns
            }
        }
    }

    /// 把 overlay 上的视图坐标平移量转换为图像空间平移量，并夹在图像范围内。
    private func moveRegion(id: UUID, viewDelta: CGSize) {
        guard let idx = item.regions.firstIndex(where: { $0.id == id }) else { return }
        let imageDelta = CGSize(
            width: viewDelta.width / displayScale,
            height: viewDelta.height / displayScale)
        var rect = item.regions[idx].rect
        let oldRect = rect
        rect.origin.x += imageDelta.width
        rect.origin.y += imageDelta.height
        // 边界钳制：区域整体保持在图像内
        rect.origin.x = max(0, min(rect.origin.x, imageSize.width - rect.width))
        rect.origin.y = max(0, min(rect.origin.y, imageSize.height - rect.height))
        item.regions[idx].rect = rect
        // #region debug-point D:move-region
        dragDebugReport(
            "D",
            "moveRegion committed",
            data: [
                "regionID": id.uuidString,
                "viewDeltaWidth": viewDelta.width,
                "viewDeltaHeight": viewDelta.height,
                "imageDeltaWidth": imageDelta.width,
                "imageDeltaHeight": imageDelta.height,
                "oldOriginX": oldRect.origin.x,
                "oldOriginY": oldRect.origin.y,
                "newOriginX": rect.origin.x,
                "newOriginY": rect.origin.y,
                "displayScale": displayScale,
            ],
            location: "EditorView.swift:moveRegion")
        // #endregion
    }

    private func viewRectToImageRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: (rect.origin.x - displayOrigin.x) / displayScale,
            y: (rect.origin.y - displayOrigin.y) / displayScale,
            width: rect.width / displayScale,
            height: rect.height / displayScale)
    }

    private func imageRectToViewRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x * displayScale + displayOrigin.x,
            y: rect.origin.y * displayScale + displayOrigin.y,
            width: rect.width * displayScale,
            height: rect.height * displayScale)
    }
}

/// 单个框选区域的 overlay：显示填充命中区 + 描边 + 删除按钮，并处理拖动位移。
/// 拖动过程中仅更新本地 `liveOffset`，松手后再一次性提交到 `item.regions[i].rect`。
///
/// 性能关键点（macOS 拖动流畅）：
/// 1. 用 `.offset` 而不是 `.position` 承载拖动位移 —— offset 是 transform-only
///    修饰符，不触发布局重算；`.position` 会走完整的 layout pass。
/// 2. 不使用 `.onHover` —— macOS 上 NSTrackingArea 随视图一起移动，拖动过程中
///    会不断触发 hover 进入/退出回调，是掉帧的常见元凶。光标切换改为在
///    DragGesture 的生命周期内 push/pop NSCursor。
/// 3. 采用 top-leading + `.offset` 做绝对定位，避免 `position` 参与布局。
/// 4. `.transaction` 关闭 offset 上的隐式动画，避免 SwiftUI 试图插值。
private struct RegionOverlay: View {
    let region: BlurRegion
    let originalImage: CoreImage.CIImage
    let viewRect: CGRect
    let displayScale: CGFloat
    let imageSize: CGSize
    let onDelete: () -> Void
    let onMove: (CGSize) -> Void

    private struct PatchData {
        let image: NSImage
        let imageRect: CGRect
    }

    @State private var liveOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var patchData: PatchData?
    @State private var renderTask: Task<Void, Never>?
    @State private var pendingRegion: BlurRegion?

    private var liveRegion: BlurRegion {
        if liveOffset == .zero { return region }
        var r = region.rect
        r.origin.x += liveOffset.width / displayScale
        r.origin.y += liveOffset.height / displayScale
        r.origin.x = max(0, min(r.origin.x, imageSize.width - r.width))
        r.origin.y = max(0, min(r.origin.y, imageSize.height - r.height))
        return BlurRegion(id: region.id, rect: r, type: region.type, intensity: region.intensity)
    }

    var body: some View {
        let color: Color = (region.type == .mosaic) ? .yellow : .cyan

        ZStack(alignment: .topLeading) {
            // 背景与图片：作为拖拽手势的唯一命中区
            ZStack(alignment: .topLeading) {
                if let patch = patchData {
                    let w = patch.imageRect.width * displayScale
                    let h = patch.imageRect.height * displayScale
                    let dx =
                        (patch.imageRect.origin.x - region.rect.origin.x) * displayScale
                        - liveOffset.width
                    let dy =
                        (patch.imageRect.origin.y - region.rect.origin.y) * displayScale
                        - liveOffset.height

                    Image(nsImage: patch.image)
                        .resizable()
                        .frame(width: w, height: h)
                        .offset(x: dx, y: dy)
                } else {
                    Rectangle()
                        .fill(color.opacity(isDragging ? 0.25 : 0.15))
                        .frame(width: viewRect.width, height: viewRect.height)
                }
            }
            .frame(width: viewRect.width, height: viewRect.height)
            .clipped()
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            NSCursor.closedHand.push()
                        }
                        liveOffset = value.translation
                        requestPatch(for: liveRegion)
                    }
                    .onEnded { value in
                        onMove(value.translation)
                        liveOffset = .zero
                        if isDragging {
                            NSCursor.pop()
                        }
                        isDragging = false
                    }
            )

            // 边框不参与交互
            Rectangle()
                .stroke(color, lineWidth: 2)
                .frame(width: viewRect.width, height: viewRect.height)
                .allowsHitTesting(false)

            // 删除按钮，层级最高，且不被底下的 DragGesture 拦截
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .background(Color.white.opacity(0.9).clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .offset(x: viewRect.width - 6, y: -10)
            .zIndex(2)
        }
        .offset(
            x: viewRect.origin.x + liveOffset.width,
            y: viewRect.origin.y + liveOffset.height
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .zIndex(isDragging ? 1 : 0)
        .transaction { $0.animation = nil }
        .onAppear { requestPatch(for: region) }
        .onChange(of: region) { newRegion in requestPatch(for: newRegion) }
    }

    /// 发起渲染请求，如果当前正忙，则覆盖挂起的请求，丢弃中间帧
    private func requestPatch(for targetRegion: BlurRegion) {
        pendingRegion = targetRegion
        if renderTask == nil {
            consumePending()
        }
    }

    /// 消费挂起的请求。保证同一时间只有一个后台线程在处理当前 Overlay 的 CoreImage 渲染。
    private func consumePending() {
        guard let regionToRender = pendingRegion else {
            renderTask = nil
            return
        }
        pendingRegion = nil

        renderTask = Task.detached(priority: .userInitiated) {
            let cgImage = ImageProcessingService.shared.renderPatch(
                region: regionToRender, from: originalImage)
            await MainActor.run {
                if let cg = cgImage {
                    self.patchData = PatchData(
                        image: NSImage(cgImage: cg, size: regionToRender.rect.size),
                        imageRect: regionToRender.rect
                    )
                }
                self.consumePending()
            }
        }
    }
}
