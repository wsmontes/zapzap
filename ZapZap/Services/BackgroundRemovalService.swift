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
