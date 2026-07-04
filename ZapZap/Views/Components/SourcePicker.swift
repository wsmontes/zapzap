import SwiftUI
import PhotosUI

struct SourcePicker: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("De onde vem a figurinha?")
                    .font(.headline)

                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        SourceOptionCard(
                            icon: "camera.fill",
                            title: "Foto",
                            subtitle: "Tire uma foto ou escolha da galeria",
                            color: .blue
                        )
                    }
                    .onChange(of: selectedPhotoItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let _ = UIImage(data: data) {
                                viewModel.selectedSource = .photo
                                dismiss()
                            }
                        }
                    }

                    NavigationLink {
                        InternetSourceView()
                    } label: {
                        SourceOptionCard(
                            icon: "globe",
                            title: "Internet",
                            subtitle: "Cole um link ou imagem da área de transferência",
                            color: .green
                        )
                    }

                    NavigationLink {
                        EmptyView()
                    } label: {
                        SourceOptionCard(
                            icon: "text.bubble.fill",
                            title: "Meme",
                            subtitle: "Adicione texto estilo meme à sua imagem",
                            color: .orange
                        )
                    }
                }
            }
            .padding()
            .navigationTitle("Nova Figurinha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

struct SourceOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct InternetSourceView: View {
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let downloadService = ImageDownloadService()

    var body: some View {
        VStack(spacing: 20) {
            TextField("Cole o link da imagem aqui...", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await downloadImage() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Baixar Imagem")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(urlText.isEmpty || isLoading)

            Divider()
                .padding(.vertical)

            Text("Ou cole uma imagem da área de transferência")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Imagem da Internet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func downloadImage() async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: urlText) else {
            errorMessage = ImageDownloadError.invalidURL.localizedDescription
            isLoading = false
            return
        }

        do {
            _ = try await downloadService.download(from: url)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
