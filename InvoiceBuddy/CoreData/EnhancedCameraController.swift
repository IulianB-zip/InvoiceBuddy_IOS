import SwiftUI
import AVFoundation
import Vision
import Combine

// Define the delegate protocol for camera controller
protocol CustomCameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CustomCameraController, didCapture image: UIImage?)
    func cameraViewControllerDidCancel(_ controller: CustomCameraController)
}

// Camera controller class that handles AVFoundation camera operations
class CustomCameraController: UIViewController, AVCapturePhotoCaptureDelegate {
    // Camera session properties
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput: AVCapturePhotoOutput!
    var videoDevice: AVCaptureDevice?
    var flashMode: AVCaptureDevice.FlashMode = .off
    weak var delegate: CustomCameraViewControllerDelegate?
    
    // Callback for image capture
    var capturedImageCallback: ((UIImage?) -> Void)?
    
    // Take photo notification observer
    private var takePhotoObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupNotificationObserver()
    }
    
    private func setupNotificationObserver() {
        // Listen for the "TakePhoto" notification that will be triggered by the SwiftUI view
        takePhotoObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TakePhoto"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.capturePhoto()
        }
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high // Use high resolution for better scanning
        
        // Get the back camera
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showAlert(message: "Could not access camera")
            return
        }
        
        videoDevice = backCamera
        
        do {
            // Configure camera input
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                showAlert(message: "Could not add camera input")
                return
            }
            
            // Configure photo output
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                // Setup camera preview
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.layer.bounds
                view.layer.addSublayer(previewLayer)
                
                // Start the session in the background to prevent UI blocking
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.captureSession.startRunning()
                }
            } else {
                showAlert(message: "Could not add photo output")
            }
        } catch {
            showAlert(message: "Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Camera Controls
    
    func capturePhoto() {
        guard captureSession?.isRunning == true else {
            // Fixed: Use correct delegate method name
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        // Use modern approach instead of deprecated isHighResolutionPhotoEnabled
        if #available(iOS 16.0, *) {
            // Just use default settings for iOS 16+
        } else {
            // For older iOS versions, avoid using high resolution if not supported
            if photoOutput.isHighResolutionCaptureEnabled {
                settings.isHighResolutionPhotoEnabled = true
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func setFlashMode(on: Bool) {
        flashMode = on ? .on : .off
        
        // Update torch if available
        updateTorch()
    }
    
    private func updateTorch() {
        guard let device = videoDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.hasTorch && device.isTorchAvailable {
                device.torchMode = flashMode == .on ? .on : .off
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Could not configure device: \(error.localizedDescription)")
        }
    }
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
        updateTorch()
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            
            // Use both callback mechanisms for flexibility
            capturedImageCallback?(nil)
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        // Convert photo to UIImage
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Could not create image from captured data")
            
            capturedImageCallback?(nil)
            delegate?.cameraViewController(self, didCapture: nil)
            return
        }
        
        // Process and enhance the image for scanning
        let enhancedImage = enhanceImageForScanning(image)
        
        // Return the image through both mechanisms
        capturedImageCallback?(enhancedImage)
        delegate?.cameraViewController(self, didCapture: enhancedImage)
    }
    
    // MARK: - Image Processing
    
    private func enhanceImageForScanning(_ image: UIImage) -> UIImage {
        // Basic image enhancement for scanning
        // This could be expanded with more sophisticated processing
        
        guard let cgImage = image.cgImage else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Apply contrast and exposure adjustments
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.1, forKey: kCIInputContrastKey) // Slightly increase contrast
        
        guard let outputImage = filter?.outputImage,
              let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - Utilities
    
    private func showAlert(message: String) {
        print("Camera error: \(message)")
        // Could show a UI alert if needed
    }
    
    func cancel() {
        delegate?.cameraViewControllerDidCancel(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop the session when view disappears
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    deinit {
        // Remove notification observer
        if let observer = takePhotoObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
