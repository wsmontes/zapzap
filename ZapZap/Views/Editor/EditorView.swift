import SwiftUI

struct EditorView: View {
    @Bindable var viewModel: EditorViewModel
    let onSave: (UIImage, [String]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if viewModel.backgroundRemoved {
                    CheckerboardPattern()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Image(uiImage: viewModel.processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(uiImage: viewModel.processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if viewModel.isProcessingBackground {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(40)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            HStack(spacing: 20) {
                EditorToolButton(
                    icon: "person.crop.rectangle",
                    label: viewModel.backgroundRemoved ? "Fundo Removido" : "Remover Fundo",
                    isActive: viewModel.backgroundRemoved
                ) {
                    Task { await viewModel.removeBackground() }
                }
                .disabled(viewModel.isProcessingBackground)

                EditorToolButton(
                    icon: "face.smiling",
                    label: "Emoji",
                    isActive: !viewModel.selectedEmojis.isEmpty
                ) {
                    viewModel.showingEmojiPicker = true
                }

                if viewModel.backgroundRemoved {
                    EditorToolButton(
                        icon: "arrow.uturn.backward",
                        label: "Desfazer",
                        isActive: false
                    ) {
                        viewModel.reset()
                    }
                }
            }
            .padding()

            Button {
                let stickerImage = viewModel.resizeToStickerDimensions()
                onSave(stickerImage, viewModel.selectedEmojis)
                dismiss()
            } label: {
                Label("Salvar Figurinha", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingEmojiPicker) {
            EmojiPicker(selectedEmojis: $viewModel.selectedEmojis)
        }
    }
}

struct EditorToolButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
            .foregroundStyle(isActive ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 16
            for x in stride(from: 0, to: size.width, by: square) {
                for y in stride(from: 0, to: size.height, by: square) {
                    let isWhite = (Int(x / square) + Int(y / square)) % 2 == 0
                    context.fill(
                        Path(CGRect(x: x, y: y, width: square, height: square)),
                        with: .color(isWhite ? Color(.systemGray5) : .white)
                    )
                }
            }
        }
    }
}
