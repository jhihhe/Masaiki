import SwiftUI
import UIKit

struct ImageStripView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.items) { item in
                    thumb(for: item)
                        .onTapGesture { viewModel.selectedItemID = item.id }
                        .contextMenu {
                            Button(role: .destructive) { viewModel.removeItem(item) } label: {
                                Label("移除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }

    private func thumb(for item: ImageItem) -> some View {
        let selected = viewModel.selectedItemID == item.id
        let image: UIImage? = {
            guard let cg = ImageProcessingService.shared.renderCGImage(item.processedImage) else { return nil }
            return UIImage(cgImage: cg)
        }()
        return Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
