import SwiftUI

struct TrimSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let maxDuration: Double

    var duration: Double {
        endTime - startTime
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Início: \(String(format: "%.1f", startTime))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Duração: \(String(format: "%.1f", duration))s")
                    .font(.caption)
                    .foregroundStyle(duration > 6.0 ? .red : .secondary)
                Spacer()
                Text("Fim: \(String(format: "%.1f", endTime))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                Slider(value: $startTime, in: 0...maxDuration, step: 0.1) {
                    Text("Início")
                }
                .tint(.green)
                .accessibilityLabel("Início do sticker animado")

                Slider(value: $endTime, in: 0...maxDuration, step: 0.1) {
                    Text("Fim")
                }
                .tint(.red)
                .accessibilityLabel("Fim do sticker animado")
            }

            if duration > 6.0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Duração máxima para stickers do WhatsApp é 6 segundos")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
