import SwiftUI

struct ExportView: View {
    @Bindable var viewModel: ExportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text(viewModel.pack.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(viewModel.pack.stickers.count) figurinhas")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                Group {
                    switch viewModel.state {
                    case .idle:
                        if viewModel.canExport {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.green)
                                Text("Pronto para exportar!")
                                    .font(.headline)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                                Text(viewModel.failureReason)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                            }
                        }

                    case .exporting:
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Criando arquivo...")
                                .font(.headline)
                        }

                    case .ready:
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("Arquivo criado!")
                                .font(.headline)

                            if let shareItem = viewModel.shareItem {
                                ShareLink(item: shareItem) {
                                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            if viewModel.hasWhatsApp {
                                Button {
                                    UIApplication.shared.open(URL(string: "whatsapp://")!)
                                } label: {
                                    Label("Abrir WhatsApp", systemImage: "arrow.right.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                    case .error(let message):
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.red)
                            Text(message)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()

                Spacer()

                if viewModel.canExport && viewModel.state != .exporting {
                    Button {
                        Task { await viewModel.export() }
                    } label: {
                        Label("Exportar para WhatsApp", systemImage: "square.and.arrow.up.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Exportar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
