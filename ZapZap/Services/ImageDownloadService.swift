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

protocol ImageDownloadServiceProtocol: AnyObject, Sendable {
    func download(from url: URL) async throws -> UIImage
}

final class ImageDownloadService: @unchecked Sendable, ImageDownloadServiceProtocol {

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
