import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolbar

                Divider()

                if let item = viewModel.selectedItem {
                    EditorView(item: item, viewModel: viewModel)
                        .id(item.id)
                } else {
                    EmptyStateView()
                }

                if !viewModel.items.isEmpty {
                    ImageStripView(viewModel: viewModel)
                        .frame(height: 84)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack {
                        Text("Masaiki")
                            .font(.headline)
                        Text("心中有步兵 眼中有骑兵")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            guard let item = viewModel.selectedItem else { return }
                            do {
                                shareURL = try viewModel.exportProcessed(item: item)
                                showingShareSheet = true
                            } catch {
                                viewModel.lastError = error.localizedDescription
                            }
                        } label: { Label("分享 / 存储到文件", systemImage: "square.and.arrow.up") }

                        Button {
                            guard let item = viewModel.selectedItem else { return }
                            Task {
                                do { try await viewModel.saveToPhotos(item: item) }
                                catch { viewModel.lastError = error.localizedDescription }
                            }
                        } label: { Label("保存到相册", systemImage: "photo.badge.plus") }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.selectedItem == nil)
                }
            }
            .onChange(of: pickerItems) { newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    await viewModel.importPickedItems(newValue)
                    pickerItems = []
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL { ShareSheet(url: url) }
            }
            .alert("出错了", isPresented: .constant(viewModel.lastError != nil)) {
                Button("好", role: .cancel) { viewModel.lastError = nil }
            } message: {
                Text(viewModel.lastError ?? "")
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("效果", selection: $viewModel.currentBlurType) {
                ForEach(BlurType.allCases) { t in
                    Text(t.localizedName).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Slider(value: $viewModel.currentIntensity, in: 0.1...1.0)
                .frame(maxWidth: 160)

            Button {
                if let item = viewModel.selectedItem { viewModel.autoDetectFaces(for: item) }
            } label: {
                Image(systemName: "face.smiling")
            }
            .disabled(viewModel.selectedItem == nil)

            Button {
                if let item = viewModel.selectedItem { viewModel.clearRegions(for: item) }
            } label: {
                Image(systemName: "eraser")
            }
            .disabled(viewModel.selectedItem?.regions.isEmpty ?? true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("点击左上角相册按钮选择图片")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
