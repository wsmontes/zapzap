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
