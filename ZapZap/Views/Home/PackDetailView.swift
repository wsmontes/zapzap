import SwiftUI
import SwiftData

struct PackDetailView: View {
    let pack: StickerPack
    @Environment(HomeViewModel.self) private var viewModel
    @State private var showingExport = false
    @State private var showingAddSticker = false

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(pack.stickers) { sticker in
                    if let image = UIImage(data: sticker.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteSticker(sticker, from: pack)
                                } label: {
                                    Label("Remover", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel("Figurinha \(sticker.emojis.joined(separator: " "))")
                    }
                }
            }
            .padding()
        }
        .navigationTitle(pack.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddSticker = true
                    } label: {
                        Label("Adicionar Figurinha", systemImage: "plus")
                    }
                    Button {
                        showingExport = true
                    } label: {
                        Label("Exportar para WhatsApp", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(pack.stickers.isEmpty)
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportView(viewModel: ExportViewModel(pack: pack))
        }
    }
}
