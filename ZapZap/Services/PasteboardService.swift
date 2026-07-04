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
