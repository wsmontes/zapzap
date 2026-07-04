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

protocol WhatsAppExporterProtocol: AnyObject, Sendable {
    func export(packData: PackExportData) async throws -> URL
    @MainActor func hasWhatsAppInstalled() -> Bool
}

final class WhatsAppExporter: @unchecked Sendable, WhatsAppExporterProtocol {

    private let fileManager: FileManager
    private let webpConverter: any WebPConverterProtocol

    init(
        fileManager: FileManager = .default,
        webpConverter: any WebPConverterProtocol = WebPConverter()
    ) {
        self.fileManager = fileManager
        self.webpConverter = webpConverter
    }

    @MainActor
    func hasWhatsAppInstalled() -> Bool {
        guard let url = URL(string: "whatsapp://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func export(packData: PackExportData) async throws -> URL {
        guard packData.isValidForExport else {
            throw WhatsAppExportError.insufficientStickers(count: packData.stickers.count)
        }

        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("zapzap_export_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: tempDir) }

        let trayURL = tempDir.appendingPathComponent("tray.png")
        try await generateTrayIcon(from: packData, to: trayURL)

        var imageFiles: [String] = []
        for (index, sticker) in packData.stickers.enumerated() {
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
            "identifier": packData.identifier,
            "name": packData.name,
            "publisher": "ZapZap",
            "tray_image_file": "tray.png",
            "image_files": imageFiles
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted) else {
            throw WhatsAppExportError.manifestCreationFailed
        }
        try jsonData.write(to: manifestURL)

        let exportURL = tempDir.deletingLastPathComponent()
            .appendingPathComponent("\(packData.name).wastickers")

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

    private func generateTrayIcon(from packData: PackExportData, to url: URL) async throws {
        let size = CGSize(width: 96, height: 96)

        let trayImage: UIImage

        if let trayData = packData.trayImageData, let img = UIImage(data: trayData) {
            trayImage = img
        } else if let firstSticker = packData.stickers.first,
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
        var archiveData = Data()
        var centralDirectory = Data()
        var entryCount: UInt16 = 0

        for fileName in files {
            let fileURL = sourceDir.appendingPathComponent(fileName)
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }

            entryCount += 1
            let localHeaderOffset = UInt32(archiveData.count)

            // Local file header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // signature
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Data($0) }) // version needed
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // flags
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // compression: stored
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // mod time
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // mod date
            let crc32 = fileData.crc32()
            localHeader.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Data($0) })
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { Data($0) }) // compressed size
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { Data($0) }) // uncompressed size
            let nameData = fileName.data(using: .utf8)!
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian) { Data($0) }) // name length
            localHeader.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // extra field length
            localHeader.append(nameData)

            archiveData.append(localHeader)
            archiveData.append(fileData)

            // Central directory entry
            var cdEntry = Data()
            cdEntry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // signature
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Data($0) }) // version made by
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(20).littleEndian) { Data($0) }) // version needed
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // flags
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // compression
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // mod time
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // mod date
            cdEntry.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Data($0) })
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { Data($0) })
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { Data($0) })
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).littleEndian) { Data($0) })
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // extra field
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // comment
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // disk start
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // internal attrs
            cdEntry.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian) { Data($0) }) // external attrs
            cdEntry.append(contentsOf: withUnsafeBytes(of: localHeaderOffset.littleEndian) { Data($0) })
            cdEntry.append(nameData)

            centralDirectory.append(cdEntry)
        }

        let cdOffset = UInt32(archiveData.count)
        archiveData.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // signature
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // disk number
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // cd disk
        eocd.append(contentsOf: withUnsafeBytes(of: entryCount.littleEndian) { Data($0) }) // entries this disk
        eocd.append(contentsOf: withUnsafeBytes(of: entryCount.littleEndian) { Data($0) }) // total entries
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirectory.count).littleEndian) { Data($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: cdOffset.littleEndian) { Data($0) })
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian) { Data($0) }) // comment length

        archiveData.append(eocd)

        do {
            try archiveData.write(to: destination)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - CRC32

extension Data {
    func crc32() -> UInt32 {
        return self.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UInt32 in
            var crc: UInt32 = 0xFFFF_FFFF
            let table = CRC32.table
            for byte in bytes.bindMemory(to: UInt8.self) {
                let index = Int((crc ^ UInt32(byte)) & 0xFF)
                crc = (crc >> 8) ^ table[index]
            }
            return crc ^ 0xFFFF_FFFF
        }
    }

    private enum CRC32 {
        static let table: [UInt32] = {
            var table = [UInt32](repeating: 0, count: 256)
            for i in 0..<256 {
                var crc = UInt32(i)
                for _ in 0..<8 {
                    if (crc & 1) != 0 {
                        crc = (crc >> 1) ^ 0xEDB8_8320
                    } else {
                        crc >>= 1
                    }
                }
                table[i] = crc
            }
            return table
        }()
    }
}
