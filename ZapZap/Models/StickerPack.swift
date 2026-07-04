import Foundation
import SwiftData

@Model
final class StickerPack {
    var identifier: String
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var stickers: [Sticker] = []
    var trayImageData: Data?

    init(
        identifier: String = UUID().uuidString,
        name: String
    ) {
        self.identifier = identifier
        self.name = name
        self.createdAt = Date()
        self.trayImageData = nil
    }

    var isValidForExport: Bool {
        (3...30).contains(stickers.count)
    }
}
