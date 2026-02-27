import AVFoundation
import Combine
import Photos
import SwiftUI
import UIKit

final class CameraSessionController: ObservableObject {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "com.xiaodao.luma.camera")
    private var configured = false
    private let photoOutput = AVCapturePhotoOutput()
    private var photoDelegates: [PhotoCaptureDelegate] = []

    func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        queue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            self.session.inputs.forEach { self.session.removeInput($0) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.startRunning()
        }
    }

    func startRunning() {
        queue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto() {
        queue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            let delegate = PhotoCaptureDelegate { [weak self] data in
                self?.savePhotoData(data)
            } onFinish: { [weak self] delegate in
                self?.queue.async {
                    self?.photoDelegates.removeAll { $0 === delegate }
                }
            }
            self.photoDelegates.append(delegate)
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private func savePhotoData(_ data: Data?) {
        guard let data else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                request.addResource(with: .photo, data: data, options: options)
            }
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onPhotoData: @Sendable (Data?) -> Void
    private let onFinish: @Sendable (PhotoCaptureDelegate) -> Void

    init(
        onPhotoData: @escaping @Sendable (Data?) -> Void,
        onFinish: @escaping @Sendable (PhotoCaptureDelegate) -> Void
    ) {
        self.onPhotoData = onPhotoData
        self.onFinish = onFinish
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil else {
            onPhotoData(nil)
            return
        }
        onPhotoData(photo.fileDataRepresentation())
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        onFinish(self)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool = true

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        if let connection = uiView.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            return AVCaptureVideoPreviewLayer()
        }
        return layer
    }
}
