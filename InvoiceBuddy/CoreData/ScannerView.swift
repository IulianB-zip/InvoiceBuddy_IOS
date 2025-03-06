// ScannerView.swift
import SwiftUI
import AVFoundation
import Vision

struct ScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var isScanning = false
    @State private var scannedData: ScannedInvoiceData?
    @State private var showingAddInvoice = false
    @State private var flashOn = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isScanning {
                    ZStack {
                        CameraView(
                            scannedData: $scannedData,
                            isScanning: $isScanning,
                            errorMessage: $errorMessage,
                            flashOn: $flashOn
                        )
                        .edgesIgnoringSafeArea(.all)
                        
                        VStack {
                            Spacer()
                            
                            // Scan overlay with target frame
                            ScanFrameView()
                                .frame(width: 250, height: 250)
                            
                            Spacer()
                            
                            // Controls
                            HStack {
                                Button(action: {
                                    isScanning = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    flashOn.toggle()
                                }) {
                                    Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 72))
                            .foregroundColor(.blue)
                        
                        Text("Scan invoice QR code or barcode")
                            .font(.headline)
                        
                        Text("Position the code within the camera frame")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            checkCameraPermission()
                        }) {
                            Text("Start Scanning")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                        
                        // Manual entry option
                        Button(action: {
                            showingAddInvoice = true
                        }) {
                            Text("Enter Manually")
                                .font(.subheadline)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan Invoice")
            .onChange(of: scannedData) { newValue in
                if newValue != nil {
                    // Process scanned data
                    showingAddInvoice = true
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                AddInvoiceView(prefillData: scannedData)
                    .environmentObject(dataManager)
                    .onDisappear {
                        // Reset scanned data when the sheet is dismissed
                        scannedData = nil
                    }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Scanning Error"),
                    message: Text(errorMessage ?? "Unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: errorMessage) { newValue in
                if newValue != nil {
                    showError = true
                }
            }
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Permission already granted
            isScanning = true
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isScanning = true
                    } else {
                        errorMessage = "Camera permission is required to scan invoices"
                    }
                }
            }
        case .denied, .restricted:
            // Permission denied
            errorMessage = "Camera permission is required. Please enable it in Settings"
        @unknown default:
            errorMessage = "Unknown camera permission error"
        }
    }
}

// A view that displays a frame for the user to position the QR code/barcode
struct ScanFrameView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
            
            // Corner brackets
            ForEach(0..<4) { corner in
                Path { path in
                    let size: CGFloat = 30
                    let cornerRadius: CGFloat = 12
                    let width: CGFloat = 3
                    
                    var x: CGFloat = -125 + cornerRadius
                    var y: CGFloat = -125 + cornerRadius
                    
                    if corner == 1 || corner == 3 {
                        x = 125 - cornerRadius - size
                    }
                    if corner == 2 || corner == 3 {
                        y = 125 - cornerRadius - size
                    }
                    
                    var startAngle: CGFloat = 0
                    var endAngle: CGFloat = 0
                    
                    switch corner {
                    case 0: // Top left
                        startAngle = .pi
                        endAngle = 3 * .pi / 2
                    case 1: // Top right
                        startAngle = 3 * .pi / 2
                        endAngle = 0
                    case 2: // Bottom left
                        startAngle = .pi / 2
                        endAngle = .pi
                    case 3: // Bottom right
                        startAngle = 0
                        endAngle = .pi / 2
                    default:
                        break
                    }
                    
                    path.addArc(
                        center: CGPoint(x: x, y: y),
                        radius: cornerRadius,
                        startAngle: Angle(radians: Double(startAngle)),
                        endAngle: Angle(radians: Double(endAngle)),
                        clockwise: false
                    )
                }
                .stroke(Color.green, lineWidth: 5)
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var scannedData: ScannedInvoiceData?
    @Binding var isScanning: Bool
    @Binding var errorMessage: String?
    @Binding var flashOn: Bool
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // Update flash state
        uiViewController.toggleFlash(on: flashOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        var parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didFindScannedData(_ data: String) {
            let parsedData = ScannedInvoiceData(rawData: data)
            parent.scannedData = parsedData
            parent.isScanning = false
        }
        
        func didEncounterError(_ error: String) {
            parent.errorMessage = error
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindScannedData(_ data: String)
    func didEncounterError(_ error: String)
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDevice: AVCaptureDevice?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didEncounterError("Camera not available")
            return
        }
        
        videoDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didEncounterError("Failed to initialize camera: \(error.localizedDescription)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didEncounterError("Camera input not supported")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .qr,
                .ean8,
                .ean13,
                .pdf417,
                .code128,
                .code39,
                .code93,
                .itf14,
                .dataMatrix
            ]
        } else {
            delegate?.didEncounterError("Metadata scanning not supported")
            return
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = captureSession
        self.previewLayer = previewLayer
        
        // Start the capture session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func toggleFlash(on: Bool) {
        guard let device = videoDevice else { return }
        
        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                delegate?.didEncounterError("Could not toggle flash: \(error.localizedDescription)")
            }
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            
            // Play a system sound and vibrate
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            // Pass the scanned data to the delegate
            delegate?.didFindScannedData(stringValue)
            
            // Stop the capture session
            captureSession?.stopRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

