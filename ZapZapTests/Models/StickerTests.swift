import Testing
import Foundation
@testable import ZapZap

@Suite struct StickerTests {

    @Test("Sticker initializes with required properties")
    func testStickerInitialization() {
        let sampleImageData = Data([0x00, 0x01, 0x02])
        let sticker = Sticker(
            id: "test-id",
            imageData: sampleImageData,
            emojis: ["😎", "🔥"],
            isAnimated: false,
            sourceTypeRaw: "photo"
        )

        #expect(sticker.id == "test-id")
        #expect(sticker.imageData == sampleImageData)
        #expect(sticker.emojis == ["😎", "🔥"])
        #expect(sticker.isAnimated == false)
        #expect(sticker.sourceTypeRaw == "photo")
        #expect(sticker.pack == nil)
    }

    @Test("Sticker accepts animated flag")
    func testStickerAnimated() {
        let sticker = Sticker(
            id: "animated-1",
            imageData: Data(),
            emojis: ["🎬"],
            isAnimated: true,
            sourceTypeRaw: "gif"
        )

        #expect(sticker.isAnimated == true)
    }

    @Test("Sticker has valid UUID by default")
    func testStickerDefaultID() {
        let sticker = Sticker(
            imageData: Data(),
            emojis: [],
            isAnimated: false,
            sourceTypeRaw: "photo"
        )

        #expect(!sticker.id.isEmpty)
        #expect(UUID(uuidString: sticker.id) != nil)
    }
}
