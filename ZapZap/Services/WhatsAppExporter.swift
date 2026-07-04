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

        let trayURL = tempDir.appendingPathComponent("tray.png")
        try await generateTrayIcon(from: pack, to: trayURL)

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
        let coordinator = NSFileCoordinator()
        var success = false

        coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: nil) { writeURL in
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
