import Foundation

struct StickerExportData: Sendable {
    let imageData: Data
    let isAnimated: Bool
}

struct PackExportData: Sendable {
    let identifier: String
    let name: String
    let stickers: [StickerExportData]
    let trayImageData: Data?

    var isValidForExport: Bool {
        (3...30).contains(stickers.count)
    }
}
