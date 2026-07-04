import AVFoundation
import UIKit

enum CameraPermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

protocol CameraPermissionServiceProtocol: AnyObject {
    var status: CameraPermissionStatus { get }
    func requestPermission() async -> CameraPermissionStatus
    func openSettings()
}

final class CameraPermissionService: CameraPermissionServiceProtocol {

    var status: CameraPermissionStatus {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    func requestPermission() async -> CameraPermissionStatus {
        let current = AVCaptureDevice.authorizationStatus(for: .video)

        switch current {
        case .authorized:
            return .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        case .denied, .restricted:
            return status
        @unknown default:
            return .denied
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

protocol PhotoLibraryPermissionServiceProtocol: AnyObject {
    func requestPermission() async -> Bool
}

final class PhotoLibraryPermissionService: PhotoLibraryPermissionServiceProtocol {

    func requestPermission() async -> Bool {
        // iOS 17+ uses PhotosPicker which doesn't require explicit permission
        // For UIImagePickerController fallback:
        return true
    }
}
