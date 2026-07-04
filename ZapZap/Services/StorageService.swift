import Foundation
import UIKit

enum StorageError: LocalizedError {
    case insufficientSpace(availableMB: Int64)

    var errorDescription: String? {
        switch self {
        case .insufficientSpace(let mb):
            return "Espaço insuficiente. Disponível: \(mb) MB. Libere espaço e tente novamente."
        }
    }
}

protocol StorageServiceProtocol: AnyObject {
    var freeSpaceMB: Int64 { get }
    func hasMinimumSpace(_ minimumMB: Int64) -> Bool
}

final class StorageService: StorageServiceProtocol {

    var freeSpaceMB: Int64 {
        guard let attrs = try? FileManager.default
            .attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = attrs[.systemFreeSize] as? Int64 else {
            return 0
        }
        return freeSpace / 1_000_000
    }

    func hasMinimumSpace(_ minimumMB: Int64) -> Bool {
        freeSpaceMB >= minimumMB
    }

    @MainActor
    func showStorageAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: "Armazenamento Cheio",
            message: "Seu dispositivo está com pouco espaço. Libere alguns arquivos para continuar criando figurinhas.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        return alert
    }
}
