import Foundation
import SwiftData

enum StickerSourceType: String, Codable {
    case photo
    case internet
    case meme
    case gif
    case video
}

@Model
final class Sticker {
    var id: String
    var imageData: Data
    var emojis: [String]
    var isAnimated: Bool
    var createdAt: Date
    var sourceTypeRaw: String
    var pack: StickerPack?

    init(
        id: String = UUID().uuidString,
        imageData: Data,
        emojis: [String] = [],
        isAnimated: Bool = false,
        sourceTypeRaw: String = StickerSourceType.photo.rawValue
    ) {
        self.id = id
        self.imageData = imageData
        self.emojis = emojis
        self.isAnimated = isAnimated
        self.createdAt = Date()
        self.sourceTypeRaw = sourceTypeRaw
        self.pack = nil
    }

    var sourceType: StickerSourceType {
        StickerSourceType(rawValue: sourceTypeRaw) ?? .photo
    }
}
