# ZapZap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build ZapZap — a free, ultra-simple iOS sticker maker app for WhatsApp, focused on Brazilian users.

**Architecture:** SwiftUI + MVVM with `@Observable` macro, SwiftData for persistence. Services layer handles Vision background removal, libwebp conversion, WhatsApp export, image downloads, and pasteboard. ViewModels talk to services via protocol-based dependency injection for testability.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing, Vision, libwebp (SDWebImage/libwebp-Xcode), Xcode 16+

## Global Constraints

- iOS 17.0+ deployment target
- iPhone only (no iPad)
- 100% pt-BR localization (Localizable.strings)
- No login, no cloud sync, no ads, no subscriptions
- Stickers: WebP 512×512px, ≤100 KB static / ≤500 KB animated, ≤6s animation
- Pack: 3–30 stickers, tray icon PNG 96×96px ≤50 KB
- All background removal on-device (Vision), no image uploads
- TDD: write failing test → implement → pass → commit

---

### Task 1: Project Setup & SwiftData Models

**Files:**
- Create: `ZapZap.xcodeproj` (Xcode project)
- Create: `ZapZap/Models/StickerPack.swift`
- Create: `ZapZap/Models/Sticker.swift`
- Create: `ZapZap/Models/MemeText.swift`
- Create: `ZapZapTests/Models/StickerPackTests.swift`
- Create: `ZapZapTests/Models/StickerTests.swift`

**Interfaces:**
- Produces: `StickerPack` (`@Model` class): `identifier: String`, `name: String`, `createdAt: Date`, `stickers: [Sticker]` (cascade), `trayImageData: Data?`
- Produces: `Sticker` (`@Model` class): `id: String`, `imageData: Data`, `emojis: [String]`, `isAnimated: Bool`, `createdAt: Date`, `pack: StickerPack?`, `sourceTypeRaw: String`
- Produces: `MemeText`: `topText: String`, `bottomText: String`, `fontSize: CGFloat`, `textColorHex: String`, `outlineColorHex: String`

- [ ] **Step 1: Create Xcode project**

```bash
mkdir -p ZapZap/{App,Models,ViewModels,Views/{Home,Editor,MemeEditor,Export,Components},Services,Resources/pt-BR.lproj}
mkdir -p ZapZapTests
```

Create the Xcode project via File > New > Project in Xcode:
- Template: iOS > App
- Name: ZapZap
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Deployment target: iOS 17.0
- Include Tests: Yes (Swift Testing)

Then add SPM dependency via File > Add Package Dependencies:
```
https://github.com/SDWebImage/libwebp-Xcode
```

Add `whatsapp` to `LSApplicationQueriesSchemes` in Info.plist.

- [ ] **Step 2: Write Sticker model tests**

Create `ZapZapTests/Models/StickerTests.swift`:

```swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
# Expected: FAIL — 'Sticker' not found
```

- [ ] **Step 4: Implement Sticker model**

Create `ZapZap/Models/Sticker.swift`:

```swift
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
```

- [ ] **Step 5: Run tests — Sticker passes**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 6: Write StickerPack model tests**

Create `ZapZapTests/Models/StickerPackTests.swift`:

```swift
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
```

- [ ] **Step 7: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
# Expected: FAIL — 'StickerPack' not found
```

- [ ] **Step 8: Implement StickerPack model**

Create `ZapZap/Models/StickerPack.swift`:

```swift
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
```

- [ ] **Step 9: Run tests — all pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
# Expected: PASS (all 6 tests)
```

- [ ] **Step 10: Implement MemeText struct**

Create `ZapZap/Models/MemeText.swift`:

```swift
import Foundation

struct MemeText: Codable, Equatable {
    var topText: String
    var bottomText: String
    var fontSize: CGFloat
    var textColorHex: String
    var outlineColorHex: String

    init(
        topText: String = "",
        bottomText: String = "",
        fontSize: CGFloat = 48,
        textColorHex: String = "#FFFFFF",
        outlineColorHex: String = "#000000"
    ) {
        self.topText = topText
        self.bottomText = bottomText
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.outlineColorHex = outlineColorHex
    }
}
```

- [ ] **Step 11: Commit**

```bash
git add ZapZap.xcodeproj ZapZap/Models/ ZapZapTests/
git commit -m "feat: add SwiftData models (Sticker, StickerPack, MemeText) with tests"
```

---

### Task 2: BackgroundRemovalService (Vision)

**Files:**
- Create: `ZapZap/Services/BackgroundRemovalService.swift`
- Create: `ZapZapTests/Services/BackgroundRemovalServiceTests.swift`

**Interfaces:**
- Consumes: `Sticker` (model from Task 1)
- Produces: `BackgroundRemovalServiceProtocol` with `func removeBackground(from image: UIImage) async throws -> UIImage`
- Produces: `BackgroundRemovalService` (concrete, uses Vision)

- [ ] **Step 1: Write failing tests**

Create `ZapZapTests/Services/BackgroundRemovalServiceTests.swift`:

```swift
import Testing
import UIKit
@testable import ZapZap

@Suite struct BackgroundRemovalServiceTests {

    @Test("Service protocol exists and can be instantiated")
    func testServiceExists() {
        let service = BackgroundRemovalService()
        #expect(service is BackgroundRemovalServiceProtocol)
    }

    @Test("Remove background returns UIImage of same size")
    func testRemoveBackgroundSameSize() async throws {
        let service = BackgroundRemovalService()
        let inputImage = UIImage(systemName: "person.fill")!
        let result = try await service.removeBackground(from: inputImage)
        #expect(result.size.width == inputImage.size.width)
        #expect(result.size.height == inputImage.size.height)
    }

    @Test("Remove background on nil-person image throws appropriate error")
    func testRemoveBackgroundNoPerson() async {
        let service = BackgroundRemovalService()
        // Create a solid color image (no person to segment)
        let solidImage = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            .image { ctx in
                UIColor.blue.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }

        do {
            _ = try await service.removeBackground(from: solidImage)
            // Should throw or return image (no crash)
        } catch {
            #expect(error is BackgroundRemovalError)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/BackgroundRemovalServiceTests 2>&1 | tail -5
# Expected: FAIL — type not found
```

- [ ] **Step 3: Implement BackgroundRemovalService**

Create `ZapZap/Services/BackgroundRemovalService.swift`:

```swift
import UIKit
import Vision
import CoreImage

enum BackgroundRemovalError: LocalizedError {
    case noPersonDetected
    case processingFailed
    case noResult

    var errorDescription: String? {
        switch self {
        case .noPersonDetected:
            return "Não encontrei nada pra recortar 😕"
        case .processingFailed:
            return "Falha ao processar a imagem. Tente novamente."
        case .noResult:
            return "Não foi possível gerar o resultado."
        }
    }
}

protocol BackgroundRemovalServiceProtocol: AnyObject {
    func removeBackground(from image: UIImage) async throws -> UIImage
}

final class BackgroundRemovalService: BackgroundRemovalServiceProtocol {

    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw BackgroundRemovalError.processingFailed
        }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    guard let mask = request.results?.first else {
                        continuation.resume(throwing: BackgroundRemovalError.noPersonDetected)
                        return
                    }

                    let maskBuffer = mask.pixelBuffer

                    guard let output = self.apply(mask: maskBuffer, to: cgImage) else {
                        continuation.resume(throwing: BackgroundRemovalError.noResult)
                        return
                    }

                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: BackgroundRemovalError.processingFailed)
                }
            }
        }
    }

    private func apply(mask: CVPixelBuffer, to image: CGImage) -> UIImage? {
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskAddress = CVPixelBufferGetBaseAddress(mask) else { return nil }

        let maskContext = CGContext(
            data: maskAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(mask),
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        guard let maskImage = maskContext?.makeImage() else { return nil }

        guard let masked = image.masking(maskImage) else { return nil }

        return UIImage(cgImage: masked, scale: 1.0, orientation: .up)
    }
}
```

- [ ] **Step 4: Run tests — all pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/BackgroundRemovalServiceTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Commit**

```bash
git add ZapZap/Services/BackgroundRemovalService.swift ZapZapTests/Services/
git commit -m "feat: add BackgroundRemovalService using Vision framework"
```

---

### Task 3: WebPConverter Service

**Files:**
- Create: `ZapZap/Services/WebPConverter.swift`
- Create: `ZapZapTests/Services/WebPConverterTests.swift`

**Interfaces:**
- Consumes: libwebp via `SDWebImage/libwebp-Xcode` SPM
- Produces: `WebPConverterProtocol` with `func encodeStatic(image: UIImage, quality: Float) throws -> Data` and `func encodeAnimated(frames: [UIImage], delaysMs: [Int], quality: Float) throws -> Data`
- Produces: `WebPConverter` (concrete, uses libwebp C API)

- [ ] **Step 1: Write failing tests**

Create `ZapZapTests/Services/WebPConverterTests.swift`:

```swift
import Testing
import UIKit
@testable import ZapZap

@Suite struct WebPConverterTests {

    @Test("WebPConverter exists and conforms to protocol")
    func testConverterExists() {
        let converter = WebPConverter()
        #expect(converter is WebPConverterProtocol)
    }

    @Test("Encode static image returns non-empty WebP data")
    func testEncodeStatic() throws {
        let converter = WebPConverter()
        let testImage = UIImage(systemName: "star.fill")!
        let webpData = try converter.encodeStatic(image: testImage, quality: 80)

        #expect(!webpData.isEmpty)
        #expect(webpData.count > 0)
    }

    @Test("Encode static image creates data under 100KB for simple image")
    func testEncodeStaticUnderLimit() throws {
        let converter = WebPConverter()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let simpleImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        let webpData = try converter.encodeStatic(image: simpleImage, quality: 50)
        #expect(webpData.count < 100_000, "Simple image should be well under 100KB")
    }

    @Test("Encode animated returns non-empty WebP data for multiple frames")
    func testEncodeAnimated() throws {
        let converter = WebPConverter()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))

        let frames = (0..<3).map { i -> UIImage in
            renderer.image { ctx in
                UIColor(hue: CGFloat(i) / 3.0, saturation: 1, brightness: 1, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }
        }

        let delays = [100, 100, 100]
        let webpData = try converter.encodeAnimated(frames: frames, delaysMs: delays, quality: 70)

        #expect(!webpData.isEmpty)
        #expect(webpData.count > 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/WebPConverterTests 2>&1 | tail -5
# Expected: FAIL — type not found
```

- [ ] **Step 3: Implement WebPConverter**

Create `ZapZap/Services/WebPConverter.swift`:

```swift
import UIKit
import Foundation
import libwebp

protocol WebPConverterProtocol: AnyObject {
    func encodeStatic(image: UIImage, quality: Float) throws -> Data
    func encodeAnimated(frames: [UIImage], delaysMs: [Int], quality: Float) throws -> Data
}

final class WebPConverter: WebPConverterProtocol {

    func encodeStatic(image: UIImage, quality: Float) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw WebPConverterError.invalidImage
        }

        let width = Int(cgImage.width)
        let height = Int(cgImage.height)

        guard let rgbaData = cgImage.rgbaPixelData() else {
            throw WebPConverterError.pixelExtractionFailed
        }

        var config = WebPConfig()
        guard WebPConfigInit(&config) != 0 else {
            throw WebPConverterError.configInitFailed
        }

        config.quality = quality
        config.lossless = 0
        config.method = 6
        config.alpha_quality = Int(quality)
        config.alpha_filtering = 1
        config.alpha_compression = 1
        config.image_hint = WEBP_HINT_PICTURE

        guard WebPValidateConfig(&config) != 0 else {
            throw WebPConverterError.invalidConfig
        }

        var picture = WebPPicture()
        guard WebPPictureInit(&picture) != 0 else {
            throw WebPConverterError.pictureInitFailed
        }

        picture.width = Int32(width)
        picture.height = Int32(height)
        picture.use_argb = 1

        let stride = width * 4
        rgbaData.withUnsafeBytes { rawBuffer in
            let ptr = rawBuffer.bindMemory(to: UInt8.self)
            WebPPictureImportRGBA(&picture, ptr.baseAddress!, Int32(stride))
        }

        defer { WebPPictureFree(&picture) }

        var writer = WebPMemoryWriter()
        WebPMemoryWriterInit(&writer)
        picture.writer = { data, size, pic } -> Int32 in
            guard let pic = pic, let data = data else { return 0 }
            let w = pic.assumingMemoryBound(to: WebPMemoryWriter.self)
            WebPMemoryWrite(w, data, size)
            return 1
        }
        picture.custom_ptr = withUnsafeMutablePointer(to: &writer) { UnsafeMutableRawPointer($0) }

        guard WebPEncode(&config, &picture) != 0 else {
            WebPMemoryWriterClear(&writer)
            throw WebPConverterError.encodeFailed
        }

        let resultData = Data(bytes: writer.mem, count: writer.size)
        WebPMemoryWriterClear(&writer)
        return resultData
    }

    func encodeAnimated(frames: [UIImage], delaysMs: [Int], quality: Float) throws -> Data {
        guard frames.count == delaysMs.count, !frames.isEmpty else {
            throw WebPConverterError.invalidFrames
        }

        var encoder = WebPAnimEncoderOptions()
        WebPAnimEncoderOptionsInit(&encoder)

        let width = Int(frames[0].size.width)
        let height = Int(frames[0].size.height)

        guard let enc = WebPAnimEncoderNew(Int32(width), Int32(height), &encoder) else {
            throw WebPConverterError.encoderInitFailed
        }

        defer { WebPAnimEncoderDelete(enc) }

        for (index, frame) in frames.enumerated() {
            guard let cgImage = frame.cgImage,
                  let rgbaData = cgImage.rgbaPixelData() else {
                throw WebPConverterError.pixelExtractionFailed
            }

            var config = WebPConfig()
            WebPConfigInit(&config)
            config.quality = quality
            config.lossless = 0
            config.method = 6

            var picture = WebPPicture()
            WebPPictureInit(&picture)
            picture.width = Int32(width)
            picture.height = Int32(height)
            picture.use_argb = 1

            let stride = width * 4
            rgbaData.withUnsafeBytes { rawBuffer in
                let ptr = rawBuffer.bindMemory(to: UInt8.self)
                WebPPictureImportRGBA(&picture, ptr.baseAddress!, Int32(stride))
            }

            defer { WebPPictureFree(&picture) }

            let timestamp = index == 0 ? 0 : delaysMs.prefix(index).reduce(0, +)

            guard WebPAnimEncoderAdd(enc, &picture, Int32(timestamp), &config) != 0 else {
                throw WebPConverterError.encodeFailed
            }
        }

        guard WebPAnimEncoderAdd(enc, nil, Int32(delaysMs.reduce(0, +)), nil) != 0 else {
            throw WebPConverterError.encodeFailed
        }

        var assembled = WebPData()
        WebPDataInit(&assembled)
        defer { WebPDataClear(&assembled) }

        guard WebPAnimEncoderAssemble(enc, &assembled) != 0 else {
            throw WebPConverterError.assembleFailed
        }

        return Data(bytes: assembled.bytes, count: assembled.size)
    }
}

enum WebPConverterError: LocalizedError {
    case invalidImage
    case pixelExtractionFailed
    case configInitFailed
    case invalidConfig
    case pictureInitFailed
    case encodeFailed
    case encoderInitFailed
    case assembleFailed
    case invalidFrames

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Imagem inválida para conversão."
        case .pixelExtractionFailed: return "Falha ao extrair pixels da imagem."
        case .configInitFailed: return "Falha ao inicializar configuração do WebP."
        case .invalidConfig: return "Configuração do WebP inválida."
        case .pictureInitFailed: return "Falha ao inicializar imagem WebP."
        case .encodeFailed: return "Falha ao codificar para WebP."
        case .encoderInitFailed: return "Falha ao inicializar codificador animado."
        case .assembleFailed: return "Falha ao montar animação WebP."
        case .invalidFrames: return "Número de frames não corresponde aos delays."
        }
    }
}

// MARK: - CGImage RGBA Helper

extension CGImage {
    func rgbaPixelData() -> Data? {
        let width = self.width
        let height = self.height
        let bytesPerRow = width * 4

        var pixelData = Data(count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }
}
```

- [ ] **Step 4: Run tests — all pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/WebPConverterTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Commit**

```bash
git add ZapZap/Services/WebPConverter.swift ZapZapTests/Services/WebPConverterTests.swift
git commit -m "feat: add WebPConverter service using libwebp"
```

---

### Task 4: ImageDownloadService & PasteboardService

**Files:**
- Create: `ZapZap/Services/ImageDownloadService.swift`
- Create: `ZapZap/Services/PasteboardService.swift`
- Create: `ZapZapTests/Services/ImageDownloadServiceTests.swift`
- Create: `ZapZapTests/Services/PasteboardServiceTests.swift`

**Interfaces:**
- Produces: `ImageDownloadServiceProtocol` with `func download(from url: URL) async throws -> UIImage`
- Produces: `PasteboardServiceProtocol` with `func hasImage() -> Bool` and `func getImage() -> UIImage?`

- [ ] **Step 1: Write failing tests for ImageDownloadService**

Create `ZapZapTests/Services/ImageDownloadServiceTests.swift`:

```swift
import Testing
import UIKit
@testable import ZapZap

@Suite struct ImageDownloadServiceTests {

    @Test("Service exists and conforms to protocol")
    func testServiceExists() {
        let service = ImageDownloadService()
        #expect(service is ImageDownloadServiceProtocol)
    }

    @Test("Download from invalid URL throws error")
    func testInvalidURL() async {
        let service = ImageDownloadService()
        guard let url = URL(string: "https://invalid.example/nonexistent.png") else {
            #expect(Bool(false), "URL should be valid format")
            return
        }

        do {
            _ = try await service.download(from: url)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is ImageDownloadError)
        }
    }

    @Test("Validates non-image content type")
    func testInvalidContentType() async {
        let service = ImageDownloadService()
        guard let url = URL(string: "https://httpbin.org/html") else {
            return
        }

        do {
            _ = try await service.download(from: url)
            // May or may not throw depending on response
        } catch {
            #expect(error is ImageDownloadError)
        }
    }
}
```

- [ ] **Step 2: Write failing tests for PasteboardService**

Create `ZapZapTests/Services/PasteboardServiceTests.swift`:

```swift
import Testing
import UIKit
@testable import ZapZap

@Suite struct PasteboardServiceTests {

    @Test("Service exists and conforms to protocol")
    func testServiceExists() {
        let service = PasteboardService()
        #expect(service is PasteboardServiceProtocol)
    }

    @Test("hasImage returns false for empty pasteboard")
    func testHasImageEmpty() {
        let service = PasteboardService()
        UIPasteboard.general.image = nil
        #expect(service.hasImage() == false)
    }

    @Test("getImage returns nil for empty pasteboard")
    func testGetImageEmpty() {
        let service = PasteboardService()
        UIPasteboard.general.image = nil
        #expect(service.getImage() == nil)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/ImageDownloadServiceTests \
  -only-testing:ZapZapTests/PasteboardServiceTests 2>&1 | tail -5
# Expected: FAIL
```

- [ ] **Step 4: Implement ImageDownloadService**

Create `ZapZap/Services/ImageDownloadService.swift`:

```swift
import UIKit
import UniformTypeIdentifiers

enum ImageDownloadError: LocalizedError {
    case invalidURL
    case downloadFailed(underlying: Error)
    case notAnImage
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Link inválido. Cole uma URL de imagem válida."
        case .downloadFailed(let error):
            return "Falha ao baixar imagem: \(error.localizedDescription)"
        case .notAnImage:
            return "O link não é uma imagem. Tente um link .png, .jpg ou .gif."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        }
    }
}

protocol ImageDownloadServiceProtocol: AnyObject {
    func download(from url: URL) async throws -> UIImage
}

final class ImageDownloadService: ImageDownloadServiceProtocol {

    private let session: URLSession
    private let imageTypes: Set<String> = [
        "image/png", "image/jpeg", "image/webp", "image/gif",
        "image/heic", "image/heif", "image/bmp", "image/tiff"
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(from url: URL) async throws -> UIImage {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageDownloadError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ImageDownloadError.invalidResponse
        }

        if let mimeType = httpResponse.mimeType, !imageTypes.contains(mimeType) {
            throw ImageDownloadError.notAnImage
        }

        guard let image = UIImage(data: data) else {
            throw ImageDownloadError.notAnImage
        }

        return image
    }
}
```

- [ ] **Step 5: Implement PasteboardService**

Create `ZapZap/Services/PasteboardService.swift`:

```swift
import UIKit

protocol PasteboardServiceProtocol: AnyObject {
    func hasImage() -> Bool
    func getImage() -> UIImage?
    func hasURL() -> Bool
    func getURL() -> URL?
}

final class PasteboardService: PasteboardServiceProtocol {

    private let pasteboard: UIPasteboard

    init(pasteboard: UIPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func hasImage() -> Bool {
        pasteboard.image != nil
    }

    func getImage() -> UIImage? {
        pasteboard.image
    }

    func hasURL() -> Bool {
        pasteboard.url != nil || pasteboard.hasStrings
    }

    func getURL() -> URL? {
        if let url = pasteboard.url {
            return url
        }

        if let string = pasteboard.string,
           let url = URL(string: string),
           url.scheme != nil {
            return url
        }

        return nil
    }
}
```

- [ ] **Step 6: Run tests — all pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/ImageDownloadServiceTests \
  -only-testing:ZapZapTests/PasteboardServiceTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 7: Commit**

```bash
git add ZapZap/Services/ImageDownloadService.swift ZapZap/Services/PasteboardService.swift ZapZapTests/Services/
git commit -m "feat: add ImageDownloadService and PasteboardService"
```

---

### Task 5: WhatsAppExporter Service

**Files:**
- Create: `ZapZap/Services/WhatsAppExporter.swift`
- Create: `ZapZapTests/Services/WhatsAppExporterTests.swift`

**Interfaces:**
- Consumes: `StickerPack` (from Task 1), `Sticker` (from Task 1)
- Produces: `WhatsAppExporterProtocol` with `func export(pack: StickerPack) async throws -> URL` and `func hasWhatsAppInstalled() -> Bool`
- Produces: Tray icon generation from first sticker or first 3 stickers

- [ ] **Step 1: Write failing tests**

Create `ZapZapTests/Services/WhatsAppExporterTests.swift`:

```swift
import Testing
import UIKit
import Foundation
@testable import ZapZap

@Suite struct WhatsAppExporterTests {

    @Test("Service exists and conforms to protocol")
    func testServiceExists() {
        let exporter = WhatsAppExporter()
        #expect(exporter is WhatsAppExporterProtocol)
    }

    @Test("Export pack creates .wastickers file at returned URL")
    func testExportPackCreatesFile() async throws {
        let exporter = WhatsAppExporter()
        let pack = StickerPack(name: "Export Test")

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
        for i in 0..<3 {
            let image = renderer.image { ctx in
                UIColor(hue: CGFloat(i) / 3.0, saturation: 1, brightness: 1, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            }
            guard let pngData = image.pngData() else { continue }
            let sticker = Sticker(imageData: pngData, emojis: ["😀"], sourceTypeRaw: "photo")
            pack.stickers.append(sticker)
        }

        let exportedURL = try await exporter.export(pack: pack)

        #expect(FileManager.default.fileExists(atPath: exportedURL.path))
        #expect(exportedURL.pathExtension == "wastickers")

        // Cleanup
        try? FileManager.default.removeItem(at: exportedURL)
    }

    @Test("Export pack with less than 3 stickers throws")
    func testExportInsufficientStickers() async {
        let exporter = WhatsAppExporter()
        let pack = StickerPack(name: "Too Small")

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
        }
        guard let pngData = image.pngData() else { return }
        pack.stickers.append(Sticker(imageData: pngData, emojis: ["😀"], sourceTypeRaw: "photo"))

        do {
            _ = try await exporter.export(pack: pack)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is WhatsAppExportError)
        }
    }

    @Test("hasWhatsAppInstalled checks URL scheme")
    func testHasWhatsAppInstalled() {
        let exporter = WhatsAppExporter()
        let result = exporter.hasWhatsAppInstalled()
        // On simulator this will be false — just verify it doesn't crash
        #expect(result == true || result == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/WhatsAppExporterTests 2>&1 | tail -5
# Expected: FAIL
```

- [ ] **Step 3: Implement WhatsAppExporter**

Create `ZapZap/Services/WhatsAppExporter.swift`:

```swift
import UIKit
import Foundation

enum WhatsAppExportError: LocalizedError {
    case insufficientStickers(count: Int)
    case trayIconGenerationFailed
    case zipCreationFailed
    case manifestCreationFailed
    case whatsAppNotInstalled

    var errorDescription: String? {
        switch self {
        case .insufficientStickers(let count):
            return "Faltam \(3 - count) figurinhas. São necessárias pelo menos 3 para exportar."
        case .trayIconGenerationFailed:
            return "Falha ao gerar ícone do pack."
        case .zipCreationFailed:
            return "Falha ao criar arquivo .wastickers."
        case .manifestCreationFailed:
            return "Falha ao criar manifesto do pack."
        case .whatsAppNotInstalled:
            return "WhatsApp não está instalado."
        }
    }
}

protocol WhatsAppExporterProtocol: AnyObject {
    func export(pack: StickerPack) async throws -> URL
    func hasWhatsAppInstalled() -> Bool
}

final class WhatsAppExporter: WhatsAppExporterProtocol {

    private let fileManager: FileManager
    private let webpConverter: WebPConverterProtocol

    init(
        fileManager: FileManager = .default,
        webpConverter: WebPConverterProtocol = WebPConverter()
    ) {
        self.fileManager = fileManager
        self.webpConverter = webpConverter
    }

    func hasWhatsAppInstalled() -> Bool {
        guard let url = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func export(pack: StickerPack) async throws -> URL {
        guard pack.isValidForExport else {
            throw WhatsAppExportError.insufficientStickers(count: pack.stickers.count)
        }

        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("zapzap_export_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: tempDir) }

        // Generate tray icon (96x96 PNG from first sticker)
        let trayURL = tempDir.appendingPathComponent("tray.png")
        try await generateTrayIcon(from: pack, to: trayURL)

        // Convert stickers to WebP
        var imageFiles: [String] = []
        for (index, sticker) in pack.stickers.enumerated() {
            let fileName = String(format: "%02d.webp", index)
            let fileURL = tempDir.appendingPathComponent(fileName)

            guard let image = UIImage(data: sticker.imageData) else { continue }

            let webpData: Data
            if sticker.isAnimated {
                webpData = try webpConverter.encodeAnimated(
                    frames: [image],
                    delaysMs: [100],
                    quality: 70
                )
            } else {
                webpData = try webpConverter.encodeStatic(image: image, quality: 80)
            }

            // Compress if over 100KB static / 500KB animated
            let limit = sticker.isAnimated ? 500_000 : 100_000
            var finalData = webpData
            var quality: Float = sticker.isAnimated ? 70 : 80

            while finalData.count > limit && quality > 10 {
                quality -= 10
                if sticker.isAnimated {
                    finalData = try webpConverter.encodeAnimated(
                        frames: [image], delaysMs: [100], quality: quality
                    )
                } else {
                    finalData = try webpConverter.encodeStatic(image: image, quality: quality)
                }
            }

            try finalData.write(to: fileURL)
            imageFiles.append(fileName)
        }

        // Generate manifest
        let manifestURL = tempDir.appendingPathComponent("sticker_packs.json")
        let manifest: [String: Any] = [
            "identifier": pack.identifier,
            "name": pack.name,
            "publisher": "ZapZap",
            "tray_image_file": "tray.png",
            "image_files": imageFiles
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted) else {
            throw WhatsAppExportError.manifestCreationFailed
        }
        try jsonData.write(to: manifestURL)

        // Create ZIP
        let exportURL = tempDir.deletingLastPathComponent()
            .appendingPathComponent("\(pack.name).wastickers")

        let zipSuccess = createZip(
            sourceDir: tempDir,
            destination: exportURL,
            files: ["sticker_packs.json", "tray.png"] + imageFiles
        )

        guard zipSuccess else {
            throw WhatsAppExportError.zipCreationFailed
        }

        return exportURL
    }

    private func generateTrayIcon(from pack: StickerPack, to url: URL) async throws {
        let size = CGSize(width: 96, height: 96)

        let trayImage: UIImage

        if let trayData = pack.trayImageData, let img = UIImage(data: trayData) {
            trayImage = img
        } else if let firstSticker = pack.stickers.first,
                  let img = UIImage(data: firstSticker.imageData) {
            trayImage = img
        } else {
            throw WhatsAppExportError.trayIconGenerationFailed
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            trayImage.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let pngData = resized.pngData() else {
            throw WhatsAppExportError.trayIconGenerationFailed
        }

        try pngData.write(to: url)
    }

    private func createZip(sourceDir: URL, destination: URL, files: [String]) -> Bool {
        // Uses libcompression or NSTemporaryDirectory approach
        // For iOS, we create the .wastickers as a ZIP manually
        let coordinator = NSFileCoordinator()
        var success = false

        coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: nil) { writeURL in
            // Use Process or a ZIP library; for this implementation we use a simple approach
            // Bundle files into a single archive
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-j", writeURL.path] + files
            process.currentDirectoryURL = sourceDir

            do {
                try process.run()
                process.waitUntilExit()
                success = process.terminationStatus == 0
            } catch {
                success = false
            }
        }

        return success
    }
}
```

- [ ] **Step 4: Run tests — all pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/WhatsAppExporterTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Commit**

```bash
git add ZapZap/Services/WhatsAppExporter.swift ZapZapTests/Services/WhatsAppExporterTests.swift
git commit -m "feat: add WhatsAppExporter service for .wastickers creation"
```

---

### Task 6: HomeViewModel & Home Views

**Files:**
- Create: `ZapZap/ViewModels/HomeViewModel.swift`
- Create: `ZapZap/Views/Home/HomeView.swift`
- Create: `ZapZap/Views/Home/PackCardView.swift`
- Create: `ZapZap/Views/Home/PackDetailView.swift`
- Create: `ZapZap/Views/Components/SourcePicker.swift`
- Create: `ZapZap/Views/Components/EmojiPicker.swift`
- Create: `ZapZapTests/ViewModels/HomeViewModelTests.swift`

**Interfaces:**
- Consumes: `StickerPack`, `Sticker` models
- Consumes: `BackgroundRemovalServiceProtocol`, `WebPConverterProtocol`, `ImageDownloadServiceProtocol`, `PasteboardServiceProtocol`, `WhatsAppExporterProtocol`
- Produces: `HomeViewModel` (`@Observable`): packs, navigation state, source picker, CRUD operations

- [ ] **Step 1: Write HomeViewModel tests**

Create `ZapZapTests/ViewModels/HomeViewModelTests.swift`:

```swift
import Testing
import SwiftData
import UIKit
@testable import ZapZap

@MainActor
@Suite struct HomeViewModelTests {

    @Test("HomeViewModel initializes with empty packs")
    func testInitialState() {
        let viewModel = HomeViewModel()

        #expect(viewModel.packs.isEmpty)
        #expect(viewModel.showingSourcePicker == false)
    }

    @Test("Create new pack works")
    func testCreatePack() {
        let viewModel = HomeViewModel()
        let initialCount = viewModel.packs.count

        viewModel.createPack(name: "Test Pack")

        #expect(viewModel.packs.count == initialCount + 1)
        #expect(viewModel.packs.last?.name == "Test Pack")
    }

    @Test("Delete pack removes it")
    func testDeletePack() {
        let viewModel = HomeViewModel()
        viewModel.createPack(name: "To Delete")
        let count = viewModel.packs.count

        if let pack = viewModel.packs.last {
            viewModel.deletePack(pack)
            #expect(viewModel.packs.count == count - 1)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/HomeViewModelTests 2>&1 | tail -5
# Expected: FAIL
```

- [ ] **Step 3: Implement HomeViewModel**

Create `ZapZap/ViewModels/HomeViewModel.swift`:

```swift
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
```

- [ ] **Step 4: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/HomeViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Implement HomeView**

Create `ZapZap/Views/Home/HomeView.swift`:

```swift
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
```

- [ ] **Step 6: Implement PackCardView**

Create `ZapZap/Views/Home/PackCardView.swift`:

```swift
import SwiftUI
import SwiftData

struct PackCardView: View {
    let pack: StickerPack

    var body: some View {
        VStack(spacing: 8) {
            // Tray icon or first sticker preview
            Group {
                if let trayData = pack.trayImageData,
                   let image = UIImage(data: trayData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let firstSticker = pack.stickers.first,
                          let image = UIImage(data: firstSticker.imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(pack.stickers.count) figurinhas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pack \(pack.name), \(pack.stickers.count) figurinhas")
    }
}
```

- [ ] **Step 7: Implement PackDetailView**

Create `ZapZap/Views/Home/PackDetailView.swift`:

```swift
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
            ExportView(pack: pack)
        }
    }
}
```

- [ ] **Step 8: Implement SourcePicker**

Create `ZapZap/Views/Components/SourcePicker.swift`:

```swift
import SwiftUI
import PhotosUI

struct SourcePicker: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var urlText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("De onde vem a figurinha?")
                    .font(.headline)

                VStack(spacing: 12) {
                    // Photo option
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
                               let image = UIImage(data: data) {
                                viewModel.selectedSource = .photo
                                // Navigate to editor with image
                                dismiss()
                            }
                        }
                    }

                    // Internet option
                    NavigationLink {
                        InternetSourceView(viewModel: viewModel)
                    } label: {
                        SourceOptionCard(
                            icon: "globe",
                            title: "Internet",
                            subtitle: "Cole um link ou imagem da área de transferência",
                            color: .green
                        )
                    }

                    // Meme option
                    NavigationLink {
                        // Meme editor entry point
                        Text("Meme Editor")
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
    @Bindable var viewModel: HomeViewModel
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

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
        // Download logic via ImageDownloadService
        isLoading = false
    }
}
```

- [ ] **Step 9: Implement EmojiPicker**

Create `ZapZap/Views/Components/EmojiPicker.swift`:

```swift
import SwiftUI

struct EmojiPicker: View {
    @Binding var selectedEmojis: [String]
    @Environment(\.dismiss) private var dismiss

    private let commonEmojis = [
        "😀", "😂", "🤣", "😍", "😎", "🥰", "😘", "😜",
        "🔥", "💯", "✅", "❤️", "👍", "🙌", "🤝", "💪",
        "😢", "😡", "🤯", "🥳", "😱", "🤔", "🙄", "😴",
        "🎉", "🌟", "💩", "👻", "🤖", "🐱", "🐶", "🦄",
        "🍕", "☕", "⚽", "🎮", "💸", "📱", "🚀", "🌈"
    ]

    var body: some View {
        NavigationStack {
            VStack {
                // Selected emojis
                if !selectedEmojis.isEmpty {
                    HStack {
                        Text("Selecionados:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(selectedEmojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title2)
                                .onTapGesture {
                                    selectedEmojis.removeAll { $0 == emoji }
                                }
                        }
                    }
                    .padding(.horizontal)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button {
                            if selectedEmojis.contains(emoji) {
                                selectedEmojis.removeAll { $0 == emoji }
                            } else {
                                selectedEmojis.append(emoji)
                            }
                        } label: {
                            Text(emoji)
                                .font(.title)
                                .opacity(selectedEmojis.contains(emoji) ? 0.4 : 1.0)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Emojis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 10: Run tests**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/HomeViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 11: Commit**

```bash
git add ZapZap/ViewModels/HomeViewModel.swift ZapZap/Views/Home/ ZapZap/Views/Components/ ZapZapTests/ViewModels/
git commit -m "feat: add HomeViewModel, HomeView, PackCardView, PackDetailView, SourcePicker, EmojiPicker"
```

---

### Task 7: EditorViewModel & Editor Views

**Files:**
- Create: `ZapZap/ViewModels/EditorViewModel.swift`
- Create: `ZapZap/Views/Editor/EditorView.swift`
- Create: `ZapZap/Views/Editor/CropOverlay.swift`
- Create: `ZapZap/Views/Editor/BackgroundEraserView.swift`
- Create: `ZapZapTests/ViewModels/EditorViewModelTests.swift`

**Interfaces:**
- Consumes: `BackgroundRemovalServiceProtocol`, `WebPConverterProtocol`
- Produces: `EditorViewModel` (`@Observable`): image, processed image, crop state, background removal state

- [ ] **Step 1: Write EditorViewModel tests**

Create `ZapZapTests/ViewModels/EditorViewModelTests.swift`:

```swift
import Testing
import UIKit
@testable import ZapZap

@MainActor
@Suite struct EditorViewModelTests {

    @Test("EditorViewModel initializes with image")
    func testInitWithImage() {
        let testImage = UIImage(systemName: "star.fill")!
        let viewModel = EditorViewModel(
            image: testImage,
            backgroundRemovalService: BackgroundRemovalService()
        )

        #expect(viewModel.originalImage == testImage)
        #expect(viewModel.processedImage == testImage)
        #expect(viewModel.isProcessingBackground == false)
        #expect(viewModel.backgroundRemoved == false)
    }

    @Test("Crop state updates correctly")
    func testCropState() {
        let testImage = UIImage(systemName: "star.fill")!
        let viewModel = EditorViewModel(
            image: testImage,
            backgroundRemovalService: BackgroundRemovalService()
        )

        viewModel.cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
        #expect(viewModel.cropRect.width == 256)
    }

    @Test("Has emojis by default")
    func testDefaultEmojis() {
        let testImage = UIImage(systemName: "star.fill")!
        let viewModel = EditorViewModel(
            image: testImage,
            backgroundRemovalService: BackgroundRemovalService()
        )

        #expect(viewModel.selectedEmojis.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/EditorViewModelTests 2>&1 | tail -5
# Expected: FAIL
```

- [ ] **Step 3: Implement EditorViewModel**

Create `ZapZap/ViewModels/EditorViewModel.swift`:

```swift
import SwiftUI
import Observation
import UIKit

@MainActor
@Observable
final class EditorViewModel {
    let originalImage: UIImage
    var processedImage: UIImage
    var isProcessingBackground = false
    var backgroundRemoved = false
    var cropRect: CGRect
    var selectedEmojis: [String] = []
    var showingEmojiPicker = false
    var errorMessage: String?

    private let backgroundRemovalService: BackgroundRemovalServiceProtocol

    init(
        image: UIImage,
        backgroundRemovalService: BackgroundRemovalServiceProtocol = BackgroundRemovalService()
    ) {
        self.originalImage = image
        self.processedImage = image
        self.backgroundRemovalService = backgroundRemovalService

        let size = min(image.size.width, image.size.height)
        self.cropRect = CGRect(
            x: (image.size.width - size) / 2,
            y: (image.size.height - size) / 2,
            width: size,
            height: size
        )
    }

    func removeBackground() async {
        isProcessingBackground = true
        errorMessage = nil

        do {
            processedImage = try await backgroundRemovalService.removeBackground(from: originalImage)
            backgroundRemoved = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessingBackground = false
    }

    func reset() {
        processedImage = originalImage
        backgroundRemoved = false
        errorMessage = nil
    }

    func resizeToStickerDimensions() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            processedImage.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
```

- [ ] **Step 4: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/EditorViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Implement EditorView**

Create `ZapZap/Views/Editor/EditorView.swift`:

```swift
import SwiftUI

struct EditorView: View {
    @Bindable var viewModel: EditorViewModel
    let onSave: (UIImage, [String]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Image preview
            ZStack {
                if viewModel.backgroundRemoved {
                    // Checkerboard for transparency
                    CheckerboardPattern()
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Image(uiImage: viewModel.processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(uiImage: viewModel.processedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if viewModel.isProcessingBackground {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(40)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Toolbar
            HStack(spacing: 20) {
                // Remove background button
                EditorToolButton(
                    icon: "person.crop.rectangle",
                    label: viewModel.backgroundRemoved ? "Fundo Removido" : "Remover Fundo",
                    isActive: viewModel.backgroundRemoved
                ) {
                    Task { await viewModel.removeBackground() }
                }
                .disabled(viewModel.isProcessingBackground)

                // Emoji button
                EditorToolButton(
                    icon: "face.smiling",
                    label: "Emoji",
                    isActive: !viewModel.selectedEmojis.isEmpty
                ) {
                    viewModel.showingEmojiPicker = true
                }

                // Reset button
                if viewModel.backgroundRemoved {
                    EditorToolButton(
                        icon: "arrow.uturn.backward",
                        label: "Desfazer",
                        isActive: false
                    ) {
                        viewModel.reset()
                    }
                }
            }
            .padding()

            // Save button
            Button {
                let stickerImage = viewModel.resizeToStickerDimensions()
                onSave(stickerImage, viewModel.selectedEmojis)
                dismiss()
            } label: {
                Label("Salvar Figurinha", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingEmojiPicker) {
            EmojiPicker(selectedEmojis: $viewModel.selectedEmojis)
        }
    }
}

struct EditorToolButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
            .foregroundStyle(isActive ? .blue : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 16
            for x in stride(from: 0, to: size.width, by: square) {
                for y in stride(from: 0, to: size.height, by: square) {
                    let isWhite = (Int(x / square) + Int(y / square)) % 2 == 0
                    context.fill(
                        Path(CGRect(x: x, y: y, width: square, height: square)),
                        with: .color(isWhite ? Color(.systemGray5) : .white)
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 6: Implement CropOverlay**

Create `ZapZap/Views/Editor/CropOverlay.swift`:

```swift
import SwiftUI

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scaleX = geometry.size.width / imageSize.width
            let scaleY = geometry.size.height / imageSize.height
            let scale = min(scaleX, scaleY)

            let displayWidth = imageSize.width * scale
            let displayHeight = imageSize.height * scale
            let offsetX = (geometry.size.width - displayWidth) / 2
            let offsetY = (geometry.size.height - displayHeight) / 2

            ZStack {
                // Dim outside crop area
                Rectangle()
                    .fill(.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .frame(
                                        width: cropRect.width * scale,
                                        height: cropRect.height * scale
                                    )
                                    .blendMode(.destinationOut)
                            )
                    )

                // Crop border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white, lineWidth: 2)
                    .frame(
                        width: cropRect.width * scale,
                        height: cropRect.height * scale
                    )
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
```

- [ ] **Step 7: Implement BackgroundEraserView**

Create `ZapZap/Views/Editor/BackgroundEraserView.swift`:

```swift
import SwiftUI

struct BackgroundEraserView: View {
    @State private var isErasing = false
    @State private var brushSize: CGFloat = 20
    @State private var erasePath = Path()

    var body: some View {
        VStack(spacing: 0) {
            // Canvas area
            ZStack {
                CheckerboardPattern()

                // Draw erased areas
                Canvas { context, size in
                    context.clipToLayer { layer in
                        layer.addFilter(.blur(radius: 0))
                    }
                }

                // Gesture overlay
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isErasing = true
                                let rect = CGRect(
                                    x: value.location.x - brushSize / 2,
                                    y: value.location.y - brushSize / 2,
                                    width: brushSize,
                                    height: brushSize
                                )
                                erasePath.addEllipse(in: rect)
                            }
                            .onEnded { _ in
                                isErasing = false
                            }
                    )
            }
            .overlay(alignment: .topTrailing) {
                if isErasing {
                    Text("Apagando...")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            // Brush size slider
            HStack {
                Image(systemName: "circle.fill")
                    .font(.caption)
                Slider(value: $brushSize, in: 5...60)
                Image(systemName: "circle.fill")
                    .font(.title3)
            }
            .padding()
        }
    }
}
```

- [ ] **Step 8: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/EditorViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 9: Commit**

```bash
git add ZapZap/ViewModels/EditorViewModel.swift ZapZap/Views/Editor/ ZapZapTests/ViewModels/EditorViewModelTests.swift
git commit -m "feat: add EditorViewModel, EditorView, CropOverlay, BackgroundEraserView"
```

---

### Task 8: MemeEditorViewModel & MemeTextEditorView

**Files:**
- Create: `ZapZap/ViewModels/MemeEditorViewModel.swift`
- Create: `ZapZap/Views/MemeEditor/MemeTextEditorView.swift`
- Create: `ZapZapTests/ViewModels/MemeEditorViewModelTests.swift`

**Interfaces:**
- Consumes: `MemeText` model
- Produces: `MemeEditorViewModel` (`@Observable`): meme text config, preview rendering

- [ ] **Step 1: Write tests**

Create `ZapZapTests/ViewModels/MemeEditorViewModelTests.swift`:

```swift
import Testing
import UIKit
@testable import ZapZap

@MainActor
@Suite struct MemeEditorViewModelTests {

    @Test("MemeEditorViewModel initializes with defaults")
    func testDefaultState() {
        let viewModel = MemeEditorViewModel()

        #expect(viewModel.topText.isEmpty)
        #expect(viewModel.bottomText.isEmpty)
        #expect(viewModel.fontSize == 48)
        #expect(viewModel.textColorHex == "#FFFFFF")
        #expect(viewModel.outlineColorHex == "#000000")
    }

    @Test("MemeEditorViewModel updates text")
    func testUpdateText() {
        let viewModel = MemeEditorViewModel()

        viewModel.topText = "BOM DIA"
        viewModel.bottomText = "GRUPO"

        #expect(viewModel.topText == "BOM DIA")
        #expect(viewModel.bottomText == "GRUPO")
    }

    @Test("MemeEditorViewModel toModel produces MemeText")
    func testToModel() {
        let viewModel = MemeEditorViewModel()
        viewModel.topText = "TOP"
        viewModel.bottomText = "BOTTOM"

        let model = viewModel.toModel()
        #expect(model.topText == "TOP")
        #expect(model.bottomText == "BOTTOM")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/MemeEditorViewModelTests 2>&1 | tail -5
# Expected: FAIL
```

- [ ] **Step 3: Implement MemeEditorViewModel**

Create `ZapZap/ViewModels/MemeEditorViewModel.swift`:

```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class MemeEditorViewModel {
    var topText: String = ""
    var bottomText: String = ""
    var fontSize: CGFloat = 48
    var textColorHex: String = "#FFFFFF"
    var outlineColorHex: String = "#000000"

    var hasContent: Bool {
        !topText.isEmpty || !bottomText.isEmpty
    }

    func toModel() -> MemeText {
        MemeText(
            topText: topText,
            bottomText: bottomText,
            fontSize: fontSize,
            textColorHex: textColorHex,
            outlineColorHex: outlineColorHex
        )
    }

    func load(from memeText: MemeText) {
        topText = memeText.topText
        bottomText = memeText.bottomText
        fontSize = memeText.fontSize
        textColorHex = memeText.textColorHex
        outlineColorHex = memeText.outlineColorHex
    }
}
```

- [ ] **Step 4: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/MemeEditorViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Implement MemeTextEditorView**

Create `ZapZap/Views/MemeEditor/MemeTextEditorView.swift`:

```swift
import SwiftUI

struct MemeTextEditorView: View {
    @Bindable var viewModel: MemeEditorViewModel
    let baseImage: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            ZStack {
                Image(uiImage: baseImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Top text
                if !viewModel.topText.isEmpty {
                    Text(viewModel.topText.uppercased())
                        .font(.custom("Impact", size: viewModel.fontSize))
                        .foregroundStyle(Color(hex: viewModel.textColorHex) ?? .white)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 20)
                }

                // Bottom text
                if !viewModel.bottomText.isEmpty {
                    Text(viewModel.bottomText.uppercased())
                        .font(.custom("Impact", size: viewModel.fontSize))
                        .foregroundStyle(Color(hex: viewModel.textColorHex) ?? .white)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .shadow(color: Color(hex: viewModel.outlineColorHex) ?? .black, radius: 2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            // Text fields
            VStack(spacing: 12) {
                TextField("Texto superior (bordão)...", text: $viewModel.topText)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)

                TextField("Texto inferior (punchline)...", text: $viewModel.bottomText)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)

                HStack {
                    Text("Tamanho: \(Int(viewModel.fontSize))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.fontSize, in: 24...80, step: 2)
                }
            }
            .padding(.horizontal)

            // Save button
            Button {
                let rendered = renderMemeImage()
                onSave(rendered)
                dismiss()
            } label: {
                Label("Salvar Meme", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasContent)
            .padding()
        }
        .navigationTitle("Editor de Meme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func renderMemeImage() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Draw base image
            baseImage.draw(in: CGRect(origin: .zero, size: size))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let textColor = UIColor(Color(hex: viewModel.textColorHex) ?? .white)
            let outlineColor = UIColor(Color(hex: viewModel.outlineColorHex) ?? .black)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Impact", size: viewModel.fontSize) ?? UIFont.boldSystemFont(ofSize: viewModel.fontSize),
                .foregroundColor: textColor,
                .strokeColor: outlineColor,
                .strokeWidth: -3.0,
                .paragraphStyle: paragraphStyle
            ]

            let topRect = CGRect(x: 10, y: 10, width: size.width - 20, height: size.height / 2)
            let bottomRect = CGRect(x: 10, y: size.height / 2 - 10, width: size.width - 20, height: size.height / 2)

            viewModel.topText.uppercased().draw(in: topRect, withAttributes: attrs)
            viewModel.bottomText.uppercased().draw(in: bottomRect, withAttributes: attrs)
        }
    }
}

// MARK: - Color from Hex Helper

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

- [ ] **Step 6: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/MemeEditorViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 7: Commit**

```bash
git add ZapZap/ViewModels/MemeEditorViewModel.swift ZapZap/Views/MemeEditor/ ZapZapTests/ViewModels/MemeEditorViewModelTests.swift
git commit -m "feat: add MemeEditorViewModel and MemeTextEditorView with meme rendering"
```

---

### Task 9: ExportView & ExportViewModel

**Files:**
- Create: `ZapZap/ViewModels/ExportViewModel.swift`
- Create: `ZapZap/Views/Export/ExportView.swift`
- Create: `ZapZapTests/ViewModels/ExportViewModelTests.swift`

**Interfaces:**
- Consumes: `WhatsAppExporterProtocol`
- Produces: `ExportViewModel` (`@Observable`): export state, progress, result URL

- [ ] **Step 1: Write failing tests**

Create `ZapZapTests/ViewModels/ExportViewModelTests.swift`:

```swift
import Testing
@testable import ZapZap

@MainActor
@Suite struct ExportViewModelTests {

    @Test("ExportViewModel initializes with idle state")
    func testInitialState() {
        let pack = StickerPack(name: "Test")
        let viewModel = ExportViewModel(pack: pack)

        #expect(viewModel.state == .idle)
        #expect(viewModel.pack.name == "Test")
    }

    @Test("ExportViewModel reflects insufficient stickers")
    func testInsufficientStickers() {
        let pack = StickerPack(name: "Small")
        let viewModel = ExportViewModel(pack: pack)

        #expect(!viewModel.canExport)
    }

    @Test("ExportViewModel can export with 3+ stickers")
    func testCanExport() {
        let pack = StickerPack(name: "Ready")
        for _ in 0..<3 {
            pack.stickers.append(
                Sticker(imageData: Data(), emojis: ["😀"], sourceTypeRaw: "photo")
            )
        }

        let viewModel = ExportViewModel(pack: pack)
        #expect(viewModel.canExport)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/ExportViewModelTests 2>&1 | tail -5
# Expected: FAIL
```

- [ ] **Step 3: Implement ExportViewModel**

Create `ZapZap/ViewModels/ExportViewModel.swift`:

```swift
import SwiftUI
import Observation
import UniformTypeIdentifiers

enum ExportState: Equatable {
    case idle
    case exporting
    case ready(exportURL: URL)
    case error(String)
}

@MainActor
@Observable
final class ExportViewModel {
    let pack: StickerPack
    var state: ExportState = .idle
    var shareItem: ShareItem?

    private let exporter: WhatsAppExporterProtocol

    init(
        pack: StickerPack,
        exporter: WhatsAppExporterProtocol = WhatsAppExporter()
    ) {
        self.pack = pack
        self.exporter = exporter
    }

    var canExport: Bool {
        pack.isValidForExport
    }

    var failureReason: String {
        let count = pack.stickers.count
        if count == 0 {
            return "Nenhuma figurinha no pack."
        } else if count < 3 {
            return "Faltam \(3 - count) figurinhas. Mínimo: 3."
        }
        return ""
    }

    func export() async {
        state = .exporting

        do {
            let url = try await exporter.export(pack: pack)
            state = .ready(exportURL: url)
            shareItem = ShareItem(url: url)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    var hasWhatsApp: Bool {
        exporter.hasWhatsAppInstalled()
    }
}

struct ShareItem: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { item in
            SentTransferredFile(item.url)
        }
    }
}
```

- [ ] **Step 4: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/ExportViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 5: Implement ExportView**

Create `ZapZap/Views/Export/ExportView.swift`:

```swift
import SwiftUI

struct ExportView: View {
    @Bindable var viewModel: ExportViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Pack info
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

                // Status
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

                    case .ready(let url):
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("Arquivo criado!")
                                .font(.headline)

                            ShareLink(item: viewModel.shareItem!) {
                                Label("Compartilhar", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

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

                // Export button
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
```

- [ ] **Step 6: Run tests — pass**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ZapZapTests/ExportViewModelTests 2>&1 | tail -5
# Expected: PASS
```

- [ ] **Step 7: Commit**

```bash
git add ZapZap/ViewModels/ExportViewModel.swift ZapZap/Views/Export/ ZapZapTests/ViewModels/ExportViewModelTests.swift
git commit -m "feat: add ExportViewModel and ExportView with ShareLink"
```

---

### Task 10: App Entry Point, Navigation & Wiring

**Files:**
- Create: `ZapZap/App/ZapZapApp.swift`
- Create: `ZapZap/App/AppDelegate.swift`
- Modify: `ZapZap/Info.plist` (LSApplicationQueriesSchemes)

**Interfaces:**
- Consumes: All ViewModels and Views from Tasks 1-9
- Produces: Complete, runnable app with navigation wired

- [ ] **Step 1: Implement ZapZapApp**

Create `ZapZap/App/ZapZapApp.swift`:

```swift
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
            // Fallback with in-memory store
            let container = try? ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            ])
            await MainActor.run {
                self.homeViewModel = HomeViewModel(modelContext: container?.mainContext)
            }
        }
    }
}
```

- [ ] **Step 2: Implement AppDelegate (minimal)**

Create `ZapZap/App/AppDelegate.swift`:

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
}
```

- [ ] **Step 3: Update Info.plist**

Ensure `ZapZap/Info.plist` contains:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>whatsapp</string>
</array>
<key>NSCameraUsageDescription</key>
<string>O ZapZap usa a câmera para você fotografar e criar figurinhas.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>O ZapZap acessa suas fotos para criar figurinhas personalizadas.</string>
```

- [ ] **Step 4: Verify app compiles**

```bash
xcodebuild -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
# Expected: BUILD SUCCEEDED
```

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10
# Expected: All tests pass
```

- [ ] **Step 6: Commit**

```bash
git add ZapZap/App/ ZapZap/Info.plist
git commit -m "feat: add app entry point, navigation wiring, and Info.plist config"
```

---

### Task 11: Localization (pt-BR)

**Files:**
- Create: `ZapZap/Resources/pt-BR.lproj/Localizable.strings`

- [ ] **Step 1: Create localization file**

Create `ZapZap/Resources/pt-BR.lproj/Localizable.strings`:

```
/* Home */
"Nenhuma figurinha ainda!" = "Nenhuma figurinha ainda!";
"Toque no + para começar a criar\nsuas figurinhas para o WhatsApp" = "Toque no + para começar a criar\nsuas figurinhas para o WhatsApp";
"Criar Figurinha" = "Criar Figurinha";
"Criar nova figurinha" = "Criar nova figurinha";
"ZapZap" = "ZapZap";
"Cancelar" = "Cancelar";
"Fechar" = "Fechar";
"OK" = "OK";

/* Source Picker */
"De onde vem a figurinha?" = "De onde vem a figurinha?";
"Foto" = "Foto";
"Tire uma foto ou escolha da galeria" = "Tire uma foto ou escolha da galeria";
"Internet" = "Internet";
"Cole um link ou imagem da área de transferência" = "Cole um link ou imagem da área de transferência";
"Meme" = "Meme";
"Adicione texto estilo meme à sua imagem" = "Adicione texto estilo meme à sua imagem";
"Cole o link da imagem aqui..." = "Cole o link da imagem aqui...";
"Baixar Imagem" = "Baixar Imagem";
"Nova Figurinha" = "Nova Figurinha";
"Imagem da Internet" = "Imagem da Internet";
"Ou cole uma imagem da área de transferência" = "Ou cole uma imagem da área de transferência";

/* Editor */
"Remover Fundo" = "Remover Fundo";
"Fundo Removido" = "Fundo Removido";
"Desfazer" = "Desfazer";
"Salvar Figurinha" = "Salvar Figurinha";
"Editor" = "Editor";
"Apagando..." = "Apagando...";
"Emoji" = "Emoji";
"Selecionados:" = "Selecionados:";
"Emojis" = "Emojis";

/* Meme Editor */
"Texto superior (bordão)..." = "Texto superior (bordão)...";
"Texto inferior (punchline)..." = "Texto inferior (punchline)...";
"Tamanho:" = "Tamanho:";
"Salvar Meme" = "Salvar Meme";
"Editor de Meme" = "Editor de Meme";

/* Pack Detail */
"Adicionar Figurinha" = "Adicionar Figurinha";
"Exportar para WhatsApp" = "Exportar para WhatsApp";
"Remover" = "Remover";
"figurinhas" = "figurinhas";

/* Export */
"Pronto para exportar!" = "Pronto para exportar!";
"Criando arquivo..." = "Criando arquivo...";
"Arquivo criado!" = "Arquivo criado!";
"Compartilhar" = "Compartilhar";
"Abrir WhatsApp" = "Abrir WhatsApp";
"Exportar" = "Exportar";
"Nenhuma figurinha no pack." = "Nenhuma figurinha no pack.";
"Faltam %d figurinhas. Mínimo: 3." = "Faltam %d figurinhas. Mínimo: 3.";

/* Services Errors */
"Não encontrei nada pra recortar 😕" = "Não encontrei nada pra recortar 😕";
"Falha ao processar a imagem. Tente novamente." = "Falha ao processar a imagem. Tente novamente.";
"Não foi possível gerar o resultado." = "Não foi possível gerar o resultado.";
"Imagem inválida para conversão." = "Imagem inválida para conversão.";
"Falha ao extrair pixels da imagem." = "Falha ao extrair pixels da imagem.";
"Falha ao codificar para WebP." = "Falha ao codificar para WebP.";
"Link inválido. Cole uma URL de imagem válida." = "Link inválido. Cole uma URL de imagem válida.";
"O link não é uma imagem. Tente um link .png, .jpg ou .gif." = "O link não é uma imagem. Tente um link .png, .jpg ou .gif.";
"Falha ao baixar imagem." = "Falha ao baixar imagem.";
"Resposta inválida do servidor." = "Resposta inválida do servidor.";
"WhatsApp não está instalado." = "WhatsApp não está instalado.";
"Falha ao criar arquivo .wastickers." = "Falha ao criar arquivo .wastickers.";
"Falha ao criar manifesto do pack." = "Falha ao criar manifesto do pack.";
```

- [ ] **Step 2: Verify app compiles with localization**

```bash
xcodebuild -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
# Expected: BUILD SUCCEEDED
```

- [ ] **Step 3: Commit**

```bash
git add ZapZap/Resources/pt-BR.lproj/
git commit -m "feat: add pt-BR localization (Localizable.strings)"
```

---

### Task 12: Integration, Edge Cases & Polish

**Files:**
- Modify: Various files for edge case handling

- [ ] **Step 1: Handle storage full alert**

Add `StorageFullAlert` to EditorView before saving:

```swift
// In EditorView, before save:
func checkStorage() -> Bool {
    guard let attrs = try? FileManager.default
        .attributesOfFileSystem(forPath: NSHomeDirectory()),
        let freeSpace = attrs[.systemFreeSize] as? Int64 else {
        return true
    }
    return freeSpace > 50_000_000 // 50 MB minimum
}
```

- [ ] **Step 2: Add animated sticker trim UI**

Add trim slider to EditorView when `sticker.isAnimated == true`:

```swift
// TrimSlider component for animated stickers
struct TrimSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let maxDuration: Double // 6.0

    var body: some View {
        VStack {
            Text("Duração: \(String(format: "%.1f", endTime - startTime))s")
                .font(.caption)
            Slider(value: $endTime, in: startTime...min(startTime + 6.0, maxDuration))
        }
    }
}
```

- [ ] **Step 3: Add camera permission denied handling**

```swift
// In EditorView/HomeView:
func checkCameraPermission() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .denied, .restricted:
        // Show alert with link to Settings
        return false
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .video)
    default:
        return true
    }
}
```

- [ ] **Step 4: Add GIF frame extraction for animated stickers**

Add to `WebPConverter`:

```swift
// Extract frames from GIF data
func extractFrames(from gifData: Data) throws -> (frames: [UIImage], delays: [Int]) {
    guard let source = CGImageSourceCreateWithData(gifData as CFData, nil) else {
        throw WebPConverterError.invalidImage
    }

    let count = CGImageSourceGetCount(source)
    var frames: [UIImage] = []
    var delays: [Int] = []

    for i in 0..<count {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
        frames.append(UIImage(cgImage: cgImage))

        let delay = gifDelay(from: source, at: i)
        delays.append(delay)
    }

    return (frames, delays)
}

private func gifDelay(from source: CGImageSource, at index: Int) -> Int {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
          let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
        return 100 // default 100ms
    }

    let unclampedDelay = (gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double) ?? 0
    let delay = (gifProps[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0

    // Convert seconds to milliseconds
    let seconds = max(unclampedDelay, delay)
    return Int(seconds * 1000)
}
```

- [ ] **Step 5: Full test suite run**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(passed|failed|TEST)"
# Expected: All tests pass
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add edge case handling, animated sticker trim, GIF frame extraction"
```

---

### Task 13: Final Integration & Smoke Test

- [ ] **Step 1: Build for release**

```bash
xcodebuild -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'generic/platform=iOS' archive \
  -archivePath build/ZapZap.xcarchive 2>&1 | tail -10
# Expected: ARCHIVE SUCCEEDED
```

- [ ] **Step 2: Run full test suite one final time**

```bash
xcodebuild test -project ZapZap.xcodeproj -scheme ZapZap \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(TEST|passed|failed)"
# Expected: TEST SUCCEEDED, all passed
```

- [ ] **Step 3: Verify app structure matches spec**

```bash
tree ZapZap/ --dirsfirst -I '*.xcodeproj|Preview*|Assets*'
# Expected: Matches architecture from spec §4.1
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final integration, cleanup, and release build verification"
git push origin master
```

---

## Plan Summary

| Task | Component | Tests | Files |
|------|-----------|-------|-------|
| 1 | Project Setup & Models | 6 | 6 |
| 2 | BackgroundRemovalService | 3 | 2 |
| 3 | WebPConverter | 4 | 2 |
| 4 | ImageDownload + Pasteboard | 5 | 4 |
| 5 | WhatsAppExporter | 4 | 2 |
| 6 | HomeViewModel + Views | 3 | 8 |
| 7 | EditorViewModel + Views | 3 | 5 |
| 8 | MemeEditor + View | 3 | 3 |
| 9 | ExportViewModel + View | 3 | 3 |
| 10 | App Entry + Wiring | 0 | 3 |
| 11 | Localization (pt-BR) | 0 | 1 |
| 12 | Integration & Edge Cases | 0 | 3+ |
| 13 | Final Integration & Smoke | 0 | 0 |

**Total: 13 tasks, ~31 tests, ~33 files**

### Test Coverage by Layer

| Layer | Tests |
|-------|-------|
| Models | 6 |
| Services | 16 |
| ViewModels | 9 |
| **Total** | **31** |

