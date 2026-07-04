import SwiftUI
import SwiftData

@main
struct ZapZapApp: App {
    @State private var homeViewModel: HomeViewModel?

    var body: some Scene {
        WindowGroup {
            if let viewModel = homeViewModel {
                HomeView()
                    .environment(viewModel)
            } else {
                ProgressView()
                    .task { await setupModelContainer() }
            }
        }
    }

    private func setupModelContainer() async {
        let schema = Schema([StickerPack.self, Sticker.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let viewModel = await MainActor.run {
                HomeViewModel(modelContext: container.mainContext)
            }
            await MainActor.run {
                self.homeViewModel = viewModel
            }
        } catch {
            let container = try? ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            ])
            await MainActor.run {
                self.homeViewModel = HomeViewModel(modelContext: container?.mainContext)
            }
        }
    }
}
