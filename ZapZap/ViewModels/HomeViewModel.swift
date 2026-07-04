import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var packs: [StickerPack] = []
    var showingSourcePicker = false
    var selectedSource: StickerSourceType?
    var navigationPath = NavigationPath()

    private let modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        fetchPacks()
    }

    func fetchPacks() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<StickerPack>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        packs = (try? context.fetch(descriptor)) ?? []
    }

    func createPack(name: String) {
        let pack = StickerPack(name: name)
        modelContext?.insert(pack)
        try? modelContext?.save()
        fetchPacks()
    }

    func deletePack(_ pack: StickerPack) {
        modelContext?.delete(pack)
        try? modelContext?.save()
        fetchPacks()
    }

    func addSticker(_ sticker: Sticker, to pack: StickerPack) {
        pack.stickers.append(sticker)
        try? modelContext?.save()
        fetchPacks()
    }

    func deleteSticker(_ sticker: Sticker, from pack: StickerPack) {
        pack.stickers.removeAll { $0.id == sticker.id }
        modelContext?.delete(sticker)
        try? modelContext?.save()
        fetchPacks()
    }
}
