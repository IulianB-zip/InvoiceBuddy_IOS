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
            .onChange(of: errorMessage) { oldValue, newValue in
                if newValue != nil {
                    showError = true
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
            .onChange(of: scannedData) { oldValue, newValue in
                if newValue != nil {
                    // Process scanned data
                    showingAddInvoice = true
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
    // Frame size - can be customized or passed as parameters
    var frameWidth: CGFloat = 250
    var frameHeight: CGFloat = 250
    var cornerLength: CGFloat = 30
    var lineWidth: CGFloat = 5
    
    var body: some View {
        ZStack {
            // Main frame outline
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                .frame(width: frameWidth, height: frameHeight)
            
            // Corner brackets
            VStack {
                HStack {
                    // Top-left corner
                    CornerView(cornerLocation: .topLeft)
                    
                    Spacer()
                    
                    // Top-right corner
                    CornerView(cornerLocation: .topRight)
                }
                
                Spacer()
                
                HStack {
                    // Bottom-left corner
                    CornerView(cornerLocation: .bottomLeft)
                    
                    Spacer()
                    
                    // Bottom-right corner
                    CornerView(cornerLocation: .bottomRight)
                }
            }
            .frame(width: frameWidth, height: frameHeight)
        }
    }
    
    // Corner location enum
    enum CornerLocation {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    // Individual corner view
    struct CornerView: View {
        var cornerLocation: CornerLocation
        
        var body: some View {
            ZStack {
                // Horizontal line
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 30, height: 5)
                    .offset(x: horizontalOffset, y: 0)
                
                // Vertical line
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 5, height: 30)
                    .offset(x: 0, y: verticalOffset)
            }
        }
        
        // Calculate offsets based on corner location
        private var horizontalOffset: CGFloat {
            switch cornerLocation {
            case .topLeft, .bottomLeft:
                return 12.5
            case .topRight, .bottomRight:
                return -12.5
            }
        }
        
        private var verticalOffset: CGFloat {
            switch cornerLocation {
            case .topLeft, .topRight:
                return 12.5
            case .bottomLeft, .bottomRight:
                return -12.5
            }
        }
    }
}

struct ScanFrameView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.8)
                .edgesIgnoringSafeArea(.all)
            
            ScanFrameView()
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

