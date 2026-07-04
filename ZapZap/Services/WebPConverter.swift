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

// MARK: - GIF Frame Extraction

extension WebPConverter {
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

        guard !frames.isEmpty else {
            throw WebPConverterError.invalidImage
        }

        return (frames, delays)
    }

    private func gifDelay(from source: CGImageSource, at index: Int) -> Int {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                as? [String: Any],
              let gifProps = properties[kCGImagePropertyGIFDictionary as String]
                as? [String: Any] else {
            return 100
        }

        let unclampedDelay = (gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double) ?? 0
        let delay = (gifProps[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0
        let seconds = max(unclampedDelay, delay)
        return Int(seconds * 1000)
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
