import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @State private var newPackName = ""

    let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: Bindable(viewModel).navigationPath) {
            ScrollView {
                if viewModel.packs.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.packs) { pack in
                            NavigationLink(value: pack) {
                                PackCardView(pack: pack)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("ZapZap")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingSourcePicker = true
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Criar nova figurinha")
                    }
                }
            }
            .sheet(isPresented: Bindable(viewModel).showingSourcePicker) {
                SourcePicker(viewModel: viewModel)
            }
            .navigationDestination(for: StickerPack.self) { pack in
                PackDetailView(pack: pack)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "face.smiling")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Nenhuma figurinha ainda!")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Toque no + para começar a criar\nsuas figurinhas para o WhatsApp")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                viewModel.showingSourcePicker = true
            } label: {
                Label("Criar Figurinha", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Abre as opções de criação de figurinha")
        }
        .padding(40)
    }
}
