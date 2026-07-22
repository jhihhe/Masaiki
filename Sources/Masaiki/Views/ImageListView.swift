import SwiftUI

struct ImageListView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List(selection: $viewModel.selectedItemID) {
            Section(header: Text("已导入图片")) {
                ForEach(viewModel.items) { item in
                    ImageRow(item: item, isSelected: viewModel.selectedItemID == item.id)
                        .tag(item.id)
                        .contextMenu {
                            Button("移除") {
                                viewModel.removeItem(item)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button(action: { viewModel.importImages() }) {
                Label("导入图片", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

struct ImageRow: View {
    @ObservedObject var item: ImageItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: 44, height: 44)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .medium))
                HStack(spacing: 4) {
                    if item.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                    }
                    Text(statusText)
                        .font(.caption2)
                        .foregroundColor(statusColor)
                }
            }

            Spacer()

            Text(formattedFileSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var thumbnail: some View {
        Group {
            if let nsImage = ImageProcessingService.shared.render(item.processedImage, toSize: CGSize(width: 88, height: 88)) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.2)
            }
        }
    }

    private var statusText: String {
        if let error = item.errorMessage {
            return error
        }
        if item.isProcessing {
            return "处理中..."
        }
        if item.regions.isEmpty {
            return "未打码"
        }
        return "\(item.regions.count) 个区域"
    }

    private var statusColor: Color {
        if item.errorMessage != nil {
            return .red
        }
        if item.regions.isEmpty {
            return .secondary
        }
        return .green
    }

    private var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(item.originalFileSize), countStyle: .file)
    }
}
