import SwiftUI
import AVFoundation

/// A completely custom camera implementation that avoids using system UI
struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isScanning: Bool
    @Binding var errorMessage: String?
    @Binding var flashOn: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraViewController {
        let controller = CustomCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CustomCameraViewController, context: Context) {
        uiViewController.setFlashMode(on: flashOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CustomCameraViewControllerDelegate {
        var parent: CustomCameraView
        
        init(_ parent: CustomCameraView) {
            self.parent = parent
        }
        
        func cameraViewController(_ controller: CustomCameraViewController, didCapture image: UIImage?) {
            parent.capturedImage = image
            if image != nil {
                parent.isScanning = false
            } else {
                parent.errorMessage = "Failed to capture image"
            }
        }
        
        func cameraViewControllerDidCancel(_ controller: CustomCameraViewController) {
            parent.isScanning = false
        }
    }
}

protocol CustomCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CustomCameraViewController, didCapture image: UIImage?)
    func cameraViewControllerDidCancel(_ controller: CustomCameraViewController)
}

class CustomCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    weak var delegate: CustomCameraViewControllerDelegate?
    
    // Camera session properties
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    private var videoDevice: AVCaptureDevice?
    private var flashMode: AVCaptureDevice.FlashMode = .off
    
    // To prevent system UI conflicts
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Explicitly don't add any UI here - the UI will be rendered in SwiftUI as an overlay
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        videoDevice = backCamera
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                delegate?.cameraViewController(self, didCapture: nil)
                return
            }
            
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                // Set up preview layer
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.layer.bounds
                view.layer.addSublayer(previewLayer)
                
                // Start capture session
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
            }
        } catch {
            delegate?.cameraViewController(self, didCapture: nil)
        }
    }
    
    func setFlashMode(on: Bool) {
        flashMode = on ? .on : .off
    }
    
    func capturePhoto() {
        guard captureSession.isRunning else {
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        delegate?.cameraViewController(self, didCapture: image)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    func cancel() {
        delegate?.cameraViewControllerDidCancel(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}
