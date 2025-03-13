import SwiftUI
import AVFoundation
import Vision
import Combine

class EnhancedCameraController: UIViewController, AVCapturePhotoCaptureDelegate {
    // Camera session properties
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput: AVCapturePhotoOutput!
    var videoDevice: AVCaptureDevice?
    var flashMode: AVCaptureDevice.FlashMode = .off
    
    // Callback for image capture
    var capturedImageCallback: ((UIImage?) -> Void)?
    
    // Overlay UI elements
    private var overlayView: UIView!
    private var cancelButton: UIButton!
    private var captureButton: UIButton!
    private var flashButton: UIButton!
    private var scanFrameView: UIView!
    
    // Observer for take photo notification
    private var takePhotoObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Listen for the "TakePhoto" notification
        takePhotoObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TakePhoto"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.capturePhoto()
        }
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showAlert(message: "Unable to access camera")
            return
        }
        
        videoDevice = backCamera
        
        do {
            // Configure input
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                showAlert(message: "Could not add camera input")
                return
            }
            
            // Configure output
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                // Configure camera preview
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
                
                // Start the capture session
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
            } else {
                showAlert(message: "Could not add photo output")
            }
        } catch {
            showAlert(message: "Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Setup overlay view
        overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)
        
        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        overlayView.addSubview(cancelButton)
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 3
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        overlayView.addSubview(captureButton)
        
        // Flash button
        flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .white
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        overlayView.addSubview(flashButton)
        
        // Scan frame view
        scanFrameView = createScanFrameView()
        overlayView.addSubview(scanFrameView)
        
        setupConstraints()
    }
    
    private func createScanFrameView() -> UIView {
        let frameView = UIView()
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 12
        
        // Add corner markers
        let cornerSize: CGFloat = 20
        let lineWidth: CGFloat = 4
        let cornerColor = UIColor.green
        
        // Top-left corner
        let topLeftHorizontal = UIView()
        topLeftHorizontal.backgroundColor = cornerColor
        topLeftHorizontal.frame = CGRect(x: 0, y: 0, width: cornerSize, height: lineWidth)
        frameView.addSubview(topLeftHorizontal)
        
        let topLeftVertical = UIView()
        topLeftVertical.backgroundColor = cornerColor
        topLeftVertical.frame = CGRect(x: 0, y: 0, width: lineWidth, height: cornerSize)
        frameView.addSubview(topLeftVertical)
        
        // Top-right corner
        let topRightHorizontal = UIView()
        topRightHorizontal.backgroundColor = cornerColor
        frameView.addSubview(topRightHorizontal)
        
        let topRightVertical = UIView()
        topRightVertical.backgroundColor = cornerColor
        frameView.addSubview(topRightVertical)
        
        // Bottom-left corner
        let bottomLeftHorizontal = UIView()
        bottomLeftHorizontal.backgroundColor = cornerColor
        frameView.addSubview(bottomLeftHorizontal)
        
        let bottomLeftVertical = UIView()
        bottomLeftVertical.backgroundColor = cornerColor
        frameView.addSubview(bottomLeftVertical)
        
        // Bottom-right corner
        let bottomRightHorizontal = UIView()
        bottomRightHorizontal.backgroundColor = cornerColor
        frameView.addSubview(bottomRightHorizontal)
        
        let bottomRightVertical = UIView()
        bottomRightVertical.backgroundColor = cornerColor
        frameView.addSubview(bottomRightVertical)
        
        // Position the corners after frame is laid out
        frameView.layoutSubviews()
        
        // Set frames for corner views
        topRightHorizontal.frame = CGRect(x: frameView.bounds.width - cornerSize, y: 0, width: cornerSize, height: lineWidth)
        topRightVertical.frame = CGRect(x: frameView.bounds.width - lineWidth, y: 0, width: lineWidth, height: cornerSize)
        
        bottomLeftHorizontal.frame = CGRect(x: 0, y: frameView.bounds.height - lineWidth, width: cornerSize, height: lineWidth)
        bottomLeftVertical.frame = CGRect(x: 0, y: frameView.bounds.height - cornerSize, width: lineWidth, height: cornerSize)
        
        bottomRightHorizontal.frame = CGRect(x: frameView.bounds.width - cornerSize, y: frameView.bounds.height - lineWidth, width: cornerSize, height: lineWidth)
        bottomRightVertical.frame = CGRect(x: frameView.bounds.width - lineWidth, y: frameView.bounds.height - cornerSize, width: lineWidth, height: cornerSize)
        
        return frameView
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Cancel button constraints
            cancelButton.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            cancelButton.widthAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Capture button constraints
            captureButton.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Flash button constraints
            flashButton.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -20),
            flashButton.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Scan frame constraints
            scanFrameView.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            scanFrameView.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -50), // Slightly higher than center
            scanFrameView.widthAnchor.constraint(equalToConstant: 280),
            scanFrameView.heightAnchor.constraint(equalToConstant: 400)
        ])
    }
    
    // MARK: - Button Actions
    
    @objc private func cancelButtonTapped() {
        // Notify cancellation through a callback or delegate
        capturedImageCallback?(nil)
    }
    
    @objc private func captureButtonTapped() {
        capturePhoto()
    }
    
    @objc private func flashButtonTapped() {
        toggleFlash()
    }
    
    // MARK: - Camera Control Methods
    
    func capturePhoto() {
        guard captureSession.isRunning else {
            showAlert(message: "Camera is not ready")
            return
        }
        
        // Create photo settings
        let settings = AVCapturePhotoSettings()
        
        // Configure flash
        settings.flashMode = flashMode
        
        // Configure photo quality in a way that works on all iOS versions
        if #available(iOS 16.0, *) {
            // For iOS 16, we don't need to set anything special
            // The default settings will use the highest quality available
        } else {
            // For iOS 15 and earlier, use isHighResolutionPhotoEnabled if supported
            if photoOutput.isHighResolutionCaptureEnabled {
                settings.isHighResolutionPhotoEnabled = true
            }
        }
        
        // Capture photo
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func toggleFlash() {
        guard let device = videoDevice else { return }
        
        // Toggle flash mode
        switch flashMode {
        case .off:
            flashMode = .on
            flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        case .on:
            flashMode = .auto
            flashButton.setImage(UIImage(systemName: "bolt.badge.a.fill"), for: .normal)
        case .auto:
            flashMode = .off
            flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        @unknown default:
            flashMode = .off
            flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        }
        
        // Update torch for preview if possible
        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                if flashMode == .on {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                print("Error updating torch: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            showAlert(message: "Error capturing photo: \(error.localizedDescription)")
            capturedImageCallback?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            showAlert(message: "Could not create image from captured data")
            capturedImageCallback?(nil)
            return
        }
        
        // Return the captured image through callback
        capturedImageCallback?(image)
    }
    
    // MARK: - Helper Methods
    
    private func showAlert(message: String) {
        // Display error message
        DispatchQueue.main.async {
            print("Camera error: \(message)")
            // Alternatively could show a popup on screen
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop the session when leaving
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
        
        // Remove notification observer
        if let observer = takePhotoObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update the frame of the preview layer
        previewLayer?.frame = view.bounds
        
        // Update frame view layout
        scanFrameView.setNeedsLayout()
        scanFrameView.layoutIfNeeded()
    }
    
    deinit {
        // Remove notification observer if it wasn't removed earlier
        if let observer = takePhotoObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// SwiftUI wrapper for the camera controller
struct EnhancedCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isScanning: Bool
    @Binding var errorMessage: String?
    @Binding var flashOn: Bool
    
    func makeUIViewController(context: Context) -> EnhancedCameraController {
        let controller = EnhancedCameraController()
        controller.capturedImageCallback = { image in
            if let image = image {
                self.capturedImage = image
                self.isScanning = false
            } else {
                self.errorMessage = "Failed to capture image"
                self.isScanning = false
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: EnhancedCameraController, context: Context) {
        // Update flash state if changed
        if flashOn && uiViewController.flashMode == .off {
            uiViewController.toggleFlash()
        } else if !flashOn && uiViewController.flashMode == .on {
            uiViewController.toggleFlash()
        }
    }
}
