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

    private let exporter: any WhatsAppExporterProtocol

    init(
        pack: StickerPack,
        exporter: any WhatsAppExporterProtocol = WhatsAppExporter()
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
            // Extract pack data within MainActor context before crossing isolation boundary
            let packData = PackExportData(
                identifier: pack.identifier,
                name: pack.name,
                stickers: pack.stickers.map { sticker in
                    StickerExportData(
                        imageData: sticker.imageData,
                        isAnimated: sticker.isAnimated
                    )
                },
                trayImageData: pack.trayImageData
            )
            let url = try await exporter.export(packData: packData)
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
