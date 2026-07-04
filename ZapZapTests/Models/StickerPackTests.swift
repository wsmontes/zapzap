import Testing
import Foundation
@testable import ZapZap

@Suite struct StickerPackTests {

    @Test("StickerPack initializes with required properties")
    func testStickerPackInitialization() {
        let pack = StickerPack(
            identifier: "com.zapzap.test",
            name: "Test Pack"
        )

        #expect(pack.identifier == "com.zapzap.test")
        #expect(pack.name == "Test Pack")
        #expect(pack.stickers.isEmpty)
        #expect(pack.trayImageData == nil)
    }

    @Test("StickerPack auto-generates identifier when empty")
    func testStickerPackDefaultIdentifier() {
        let pack = StickerPack(name: "Auto ID Pack")

        #expect(!pack.identifier.isEmpty)
    }

    @Test("StickerPack sticker count is accurate")
    func testStickerPackStickerCount() {
        let pack = StickerPack(name: "Count Test")
        let sticker1 = Sticker(imageData: Data(), emojis: ["😀"], sourceTypeRaw: "photo")
        let sticker2 = Sticker(imageData: Data(), emojis: ["😂"], sourceTypeRaw: "meme")

        pack.stickers.append(sticker1)
        pack.stickers.append(sticker2)

        #expect(pack.stickers.count == 2)
    }

    @Test("StickerPack can hold 3-30 stickers for valid WhatsApp export")
    func testStickerPackExportRange() {
        let pack = StickerPack(name: "Export Test")
        let validRange = (3...30).contains(pack.stickers.count)
        // Empty pack should not be in valid range
        #expect(!validRange)

        // Add 5 stickers
        for i in 0..<5 {
            pack.stickers.append(
                Sticker(imageData: Data(), emojis: ["😀"], sourceTypeRaw: "photo")
            )
        }
        #expect((3...30).contains(pack.stickers.count))
    }
}
