import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Picker("效果", selection: $viewModel.currentBlurType) {
                    ForEach(BlurType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                VStack(alignment: .leading, spacing: 2) {
                    Text("强度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: $viewModel.currentIntensity, in: 0.1...1.0)
                        .frame(width: 120)
                }
            }

            Divider()
                .frame(height: 32)

            HStack(spacing: 8) {
                Button(action: {
                    if let item = viewModel.selectedItem {
                        viewModel.autoDetectFaces(for: item)
                    }
                }) {
                    Label("自动识别人脸", systemImage: "face.smiling")
                }
                .disabled(viewModel.selectedItem == nil)

                Button(action: {
                    if let item = viewModel.selectedItem {
                        viewModel.clearRegions(for: item)
                    }
                }) {
                    Label("清除", systemImage: "eraser")
                }
                .disabled(viewModel.selectedItem?.regions.isEmpty ?? true)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    if let item = viewModel.selectedItem {
                        viewModel.save(item: item)
                    }
                }) {
                    Label("保存当前", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItem == nil)

                Button(action: { viewModel.saveAll() }) {
                    Label("全部保存", systemImage: "square.and.arrow.down.on.square")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.items.isEmpty)
            }
        }
    }
}
