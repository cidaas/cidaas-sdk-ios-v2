//
//  FacePhotoCapture.swift
//  Cidaas
//

import UIKit

enum FacePhotoCapture {

    private static var activeSession: Session?

    typealias CaptureResult = Swift.Result<UIImage, WebAuthError>

    static func hasEncodableJPEG(_ image: UIImage) -> Bool {
        guard image.size.width > 0, image.size.height > 0 else { return false }
        return image.jpegData(compressionQuality: 0.8) != nil
    }

    static func capture(completion: @escaping (CaptureResult) -> Void) {
        onMain {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                completion(.failure(validationError("Camera is not available on this device")))
                return
            }
            guard let presenter = topViewController() else {
                completion(.failure(validationError("No view controller available to present the camera")))
                return
            }
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraDevice = UIImagePickerController.isCameraDeviceAvailable(.front) ? .front : .rear
            picker.allowsEditing = false
            let session = Session(completion: completion)
            activeSession = session
            picker.delegate = session
            presenter.present(picker, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let root: UIViewController?
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
            let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
                ?? scenes.flatMap(\.windows).first
            root = window?.rootViewController
        } else {
            root = UIApplication.shared.keyWindow?.rootViewController
        }
        guard var top = root else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        if let nav = top as? UINavigationController {
            return nav.visibleViewController ?? nav
        }
        if let tab = top as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return top
    }

    fileprivate static func validationError(_ message: String) -> WebAuthError {
        WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: message, statusCode: 417)
    }

    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private final class Session: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let completion: (CaptureResult) -> Void

        init(completion: @escaping (CaptureResult) -> Void) {
            self.completion = completion
            super.init()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage,
                  FacePhotoCapture.hasEncodableJPEG(image) else {
                activeSession = nil
                completion(.failure(FacePhotoCapture.validationError("Could not read a photo from the camera")))
                return
            }
            activeSession = nil
            completion(.success(image))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            activeSession = nil
            completion(.failure(FacePhotoCapture.validationError("Face photo capture was cancelled")))
        }
    }
}
