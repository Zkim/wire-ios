//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 

import Foundation
import MobileCoreServices
import Photos
import FLAnimatedImage

private let zmLog = ZMSLog(tag: "UI")

@objcMembers class FastTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    static let sharedDelegate = FastTransitioningDelegate()

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return VerticalTransition(offset: -180)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return VerticalTransition(offset: 180)
    }
}

final class StatusBarVideoEditorController: UIVideoEditorController {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return traitCollection.horizontalSizeClass == .regular ? .popover : .overFullScreen
    }
}

extension ConversationInputBarViewController: CameraKeyboardViewControllerDelegate {

    @objc public func createCameraKeyboardViewController() {
        guard let splitViewController = ZClientViewController.shared?.wireSplitViewController else { return }
        let cameraKeyboardViewController = CameraKeyboardViewController(splitLayoutObservable: splitViewController, imageManagerType: PHImageManager.self)
        cameraKeyboardViewController.delegate = self

        self.cameraKeyboardViewController = cameraKeyboardViewController
    }

    func cameraKeyboardViewController(_ controller: CameraKeyboardViewController, didSelectVideo videoURL: URL, duration: TimeInterval) {
        // Video can be longer than allowed to be uploaded. Then we need to add user the possibility to trim it.
        if duration > ZMUserSession.shared()!.maxVideoLength() {
            let videoEditor = StatusBarVideoEditorController()
            videoEditor.transitioningDelegate = FastTransitioningDelegate.sharedDelegate
            videoEditor.delegate = self
            videoEditor.videoMaximumDuration = ZMUserSession.shared()!.maxVideoLength()
            videoEditor.videoPath = videoURL.path
            videoEditor.videoQuality = .typeMedium

            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                self.hideCameraKeyboardViewController {
                    videoEditor.modalPresentationStyle = .popover

                    self.present(videoEditor, animated: true)

                    let popover = videoEditor.popoverPresentationController
                    popover?.sourceView = self.parent?.view

                    ///arrow point to camera button.
                    popover?.permittedArrowDirections = .down

                    popover?.sourceRect = self.photoButton.popoverSourceRect(from: self)

                    if let parentView = self.parent?.view {
                        videoEditor.preferredContentSize = parentView.frame.size
                    }
                }
            default:
                self.present(videoEditor, animated: true) {
                    }
            }
        } else {
            let context = ConfirmAssetViewController.Context(asset: .video(url: videoURL),
                                                             onConfirm: { [unowned self] (editedImage: UIImage?) in
                                                                            self.dismiss(animated: true)
                                                                            self.uploadFile(at: videoURL)
                                                                            },
                                                             onCancel: { [unowned self] in
                                                                            self.dismiss(animated: true) {
                                                                                self.mode = .camera
                                                                                self.inputBar.textView.becomeFirstResponder()
                                                                            }
                                                            })
            let confirmVideoViewController = ConfirmAssetViewController(context: context)
            confirmVideoViewController.transitioningDelegate = FastTransitioningDelegate.sharedDelegate
            confirmVideoViewController.previewTitle = self.conversation.displayName.localizedUppercase

            self.present(confirmVideoViewController, animated: true) {
            }
        }
    }

    func cameraKeyboardViewController(_ controller: CameraKeyboardViewController,
                                             didSelectImageData imageData: Data,
                                             isFromCamera: Bool,
                                             uti: String?) {
        showConfirmationForImage(imageData, isFromCamera: isFromCamera, uti: uti)
    }

    @objc func image(_ image: UIImage?, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        if let error = error {
            zmLog.error("didFinishSavingWithError: \(error)")
        }
    }

    // MARK: - Video save callback
    @objc func video(_ image: UIImage?, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        if let error = error {
            zmLog.error("Error saving video: \(error)")
        }
    }

    func cameraKeyboardViewControllerWantsToOpenFullScreenCamera(_ controller: CameraKeyboardViewController) {
        self.hideCameraKeyboardViewController {
            self.shouldRefocusKeyboardAfterImagePickerDismiss = true
            self.presentImagePicker(with: .camera,
                                    mediaTypes: [kUTTypeMovie as String, kUTTypeImage as String],
                                    allowsEditing: false,
                                    pointToView:self.photoButton.imageView)
        }
    }

    func cameraKeyboardViewControllerWantsToOpenCameraRoll(_ controller: CameraKeyboardViewController) {
        self.hideCameraKeyboardViewController {
            self.shouldRefocusKeyboardAfterImagePickerDismiss = true
            self.presentImagePicker(with: .photoLibrary,
                                    mediaTypes: [kUTTypeMovie as String, kUTTypeImage as String],
                                    allowsEditing: false,
                                    pointToView:self.photoButton.imageView)
        }
    }

    @objc
    public func showConfirmationForImage(_ imageData: Data,
                                           isFromCamera: Bool,
                                           uti: String?) {
        let mediaAsset: MediaAsset

        if uti == kUTTypeGIF as String,
           let gifImage = FLAnimatedImage(animatedGIFData: imageData),
           gifImage.frameCount > 1 {
            mediaAsset = gifImage
        } else {
            mediaAsset = UIImage(data: imageData) ?? UIImage()
        }

        let context = ConfirmAssetViewController.Context(asset: .image(mediaAsset: mediaAsset),
                                                         onConfirm: { [weak self] (editedImage: UIImage?) in
                                                                self?.dismiss(animated: true) {
                                                                    if isFromCamera {
                                                                        guard let image = UIImage(data: imageData as Data) else { return }
                                                                        let selector = #selector(ConversationInputBarViewController.image(_:didFinishSavingWithError:contextInfo:))
                                                                        UIImageWriteToSavedPhotosAlbum(image, self, selector, nil)
                                                                    }

                                                                    self?.sendController.sendMessage(withImageData: editedImage?.pngData() ?? imageData)
                                                                }
                                                            },
                                                         onCancel: { [weak self] in
                                                                        self?.dismiss(animated: true) {
                                                                            self?.mode = .camera
                                                                            self?.inputBar.textView.becomeFirstResponder()
                                                                        }
                                                                    })

        let confirmImageViewController = ConfirmAssetViewController(context: context)
        confirmImageViewController.transitioningDelegate = FastTransitioningDelegate.sharedDelegate
        confirmImageViewController.previewTitle = self.conversation.displayName.localizedUppercase

        present(confirmImageViewController, animated: true)
    }

    private func executeWithCameraRollPermission(_ closure: @escaping (_ success: Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
            switch status {
            case .authorized:
                closure(true)
            default:
                closure(false)
                break
            }
            }
        }
    }

    func convertVideoAtPath(_ inputPath: String, completion: @escaping (_ success: Bool, _ resultPath: String?, _ duration: TimeInterval) -> Void) {

        let lastPathComponent = (inputPath as NSString).lastPathComponent

        let filename: String = ((lastPathComponent as NSString).deletingPathExtension as NSString).appendingPathExtension("mp4") ?? "video.mp4"

        let videoURLAsset = AVURLAsset(url: NSURL(fileURLWithPath: inputPath) as URL)

        videoURLAsset.convert(filename: filename) { URL, videoAsset, error in
            guard let resultURL = URL, error == nil else {
                completion(false, .none, 0)
                return
            }
            completion(true, resultURL.path, CMTimeGetSeconds((videoAsset?.duration)!))

            }
    }
}

extension ConversationInputBarViewController: UIVideoEditorControllerDelegate {
    public func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        editor.dismiss(animated: true, completion: .none)
    }

    public func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        editor.dismiss(animated: true, completion: .none)

        editor.showLoadingView = true

        self.convertVideoAtPath(editedVideoPath) { (success, resultPath, duration) in
            editor.showLoadingView = false

            guard let path = resultPath, success else {
                return
            }

            self.uploadFile(at: NSURL(fileURLWithPath: path) as URL)
        }
    }

    @nonobjc public func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: NSError) {
        editor.dismiss(animated: true, completion: .none)
        zmLog.error("Video editor failed with error: \(error)")
    }
}

extension ConversationInputBarViewController: CanvasViewControllerDelegate {

    func canvasViewController(_ canvasViewController: CanvasViewController, didExportImage image: UIImage) {
        hideCameraKeyboardViewController { [weak self] in
            guard let `self` = self else { return }

            self.dismiss(animated: true, completion: {
                if let imageData = image.pngData() {
                    self.sendController.sendMessage(withImageData: imageData)
                }
            })
        }
    }

}

// MARK: - CameraViewController

extension ConversationInputBarViewController {
    @objc
    func cameraButtonPressed(_ sender: Any?) {
        if mode == .camera {
            inputBar.textView.resignFirstResponder()
            cameraKeyboardViewController = nil
            delay(0.3) {
                self.mode = .textInput
            }
        } else {
            UIApplication.wr_requestVideoAccess({ granted in
                self.executeWithCameraRollPermission() { success in
                    self.mode = .camera
                    self.inputBar.textView.becomeFirstResponder()
                }
            })
        }
    }
}
