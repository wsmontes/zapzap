import SwiftUI

struct BackgroundEraserView: View {
    @State private var isErasing = false
    @State private var brushSize: CGFloat = 20
    @State private var erasePath = Path()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                CheckerboardPattern()

                Canvas { context, size in
                    context.clipToLayer { _ in }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isErasing = true
                                let rect = CGRect(
                                    x: value.location.x - brushSize / 2,
                                    y: value.location.y - brushSize / 2,
                                    width: brushSize,
                                    height: brushSize
                                )
                                erasePath.addEllipse(in: rect)
                            }
                            .onEnded { _ in
                                isErasing = false
                            }
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isErasing {
                    Text("Apagando...")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            HStack {
                Image(systemName: "circle.fill")
                    .font(.caption)
                Slider(value: $brushSize, in: 5...60)
                Image(systemName: "circle.fill")
                    .font(.title3)
            }
            .padding()
        }
    }
}
