import SwiftUI

struct MemeTextEditorView: View {
    @Bindable var viewModel: MemeEditorViewModel
    let baseImage: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(uiImage: baseImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                if !viewModel.topText.isEmpty {
                    Text(viewModel.topText.uppercased())
                        .font(.custom("Impact", size: viewModel.fontSize))
                        .foregroundStyle(Color(hex: viewModel.textColorHex) ?? .white)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 20)
                }

                if !viewModel.bottomText.isEmpty {
                    Text(viewModel.bottomText.uppercased())
                        .font(.custom("Impact", size: viewModel.fontSize))
                        .foregroundStyle(Color(hex: viewModel.textColorHex) ?? .white)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            VStack(spacing: 12) {
                TextField("Texto superior (bordão)...", text: $viewModel.topText)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)

                TextField("Texto inferior (punchline)...", text: $viewModel.bottomText)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)

                HStack {
                    Text("Tamanho: \(Int(viewModel.fontSize))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.fontSize, in: 24...80, step: 2)
                }
            }
            .padding(.horizontal)

            Button {
                let rendered = renderMemeImage()
                onSave(rendered)
                dismiss()
            } label: {
                Label("Salvar Meme", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasContent)
            .padding()
        }
        .navigationTitle("Editor de Meme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func renderMemeImage() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            baseImage.draw(in: CGRect(origin: .zero, size: size))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let textColor = UIColor(Color(hex: viewModel.textColorHex) ?? .white)
            let outlineColor = UIColor(Color(hex: viewModel.outlineColorHex) ?? .black)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Impact", size: viewModel.fontSize) ?? UIFont.boldSystemFont(ofSize: viewModel.fontSize),
                .foregroundColor: textColor,
                .strokeColor: outlineColor,
                .strokeWidth: -3.0,
                .paragraphStyle: paragraphStyle
            ]

            let topRect = CGRect(x: 10, y: 10, width: size.width - 20, height: size.height / 2)
            let bottomRect = CGRect(x: 10, y: size.height / 2 - 10, width: size.width - 20, height: size.height / 2)

            viewModel.topText.uppercased().draw(in: topRect, withAttributes: attrs)
            viewModel.bottomText.uppercased().draw(in: bottomRect, withAttributes: attrs)
        }
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
