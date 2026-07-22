import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var isDropTarget = false

    var body: some View {
        NavigationSplitView {
            ImageListView(viewModel: viewModel)
                .frame(minWidth: 220)
        } detail: {
            VStack(spacing: 0) {
                ToolbarView(viewModel: viewModel)
                    .padding()
                Divider()
                if let selected = viewModel.selectedItem {
                    EditorView(item: selected, viewModel: viewModel)
                        .id(selected.id)
                } else {
                    EmptyStateView()
                }
            }
        }
        .navigationTitle("马赛克工具")
        .alert(item: $viewModel.saveResult) { result in
            Alert(
                title: Text("保存完成"),
                message: Text("已保存 \(result.saved) 张图片，跳过 \(result.skipped) 张未打码图片。"),
                dismissButton: .default(Text("确定"))
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
            handleDroppedProviders(providers)
            return true
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let url = item as? URL {
                    urls.append(url)
                } else if let data = item as? Data,
                          let string = String(data: data, encoding: .utf8),
                          let url = URL(string: string) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            viewModel.handleDroppedURLs(urls)
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("拖入图片或点击导入开始")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
