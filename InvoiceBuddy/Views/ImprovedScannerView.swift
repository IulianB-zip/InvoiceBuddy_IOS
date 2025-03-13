import SwiftUI
import AVFoundation
import Vision
import Combine
import PhotosUI

/// A completely redesigned scanner view that properly positions all elements
/// with significant padding to avoid any overlap with the tab bar
struct ImprovedScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var capturedImage: UIImage?
    @State private var extractedInvoiceData: InvoiceData?
    @State private var showingAddInvoice = false
    @State private var isProcessing = false
    @State private var flashOn = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPreviewSheet = false
    
    private let scanner = EnhancedInvoiceScanner()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera view
                CameraSessionView(
                    capturedImage: $capturedImage,
                    flashOn: $flashOn,
                    errorMessage: $errorMessage
                )
                .edgesIgnoringSafeArea(.all)
                
                // Content overlay
                VStack(spacing: 0) {
                    // Scan frame area
                    Spacer()
                    
                    // Scan frame with instruction
                    ScanFrameWithInstruction(
                        frameWidth: min(geometry.size.width - 40, 300),
                        // Calculate safe height to ensure nothing overlaps with tab bar
                        availableHeight: geometry.size.height * 0.8
                    )
                    
                    // Significant spacer at bottom to prevent any overlap
                    Spacer()
                        .frame(height: geometry.size.height * 0.2) // Reserve 20% of screen height for tab bar area
                }
                
                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Processing invoice...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                processImage(image)
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                showError = true
            }
        }
        .sheet(isPresented: $showPreviewSheet) {
            if let data = extractedInvoiceData {
                InvoiceDataPreviewView(
                    invoiceData: data,
                    capturedImage: capturedImage,
                    onAddInvoice: { invoice in
                        dataManager.saveInvoice(invoice)
                        cleanupAfterPreview()
                    },
                    onCancel: cleanupAfterPreview
                )
            }
        }
        .sheet(isPresented: $showingAddInvoice) {
            if let data = extractedInvoiceData {
                let scannedData = createScannedData(from: data)
                AddInvoiceView(prefillData: scannedData)
            } else {
                AddInvoiceView()
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Scanning Error"),
                message: Text(errorMessage ?? "Unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    /// Combined scan frame and instruction component with proper spacing
    struct ScanFrameWithInstruction: View {
        let frameWidth: CGFloat
        let availableHeight: CGFloat
        
        var body: some View {
            VStack(spacing: 20) { // Important: increased spacing between frame and text
                // Scan frame with transparent background
                ZStack {
                    // White border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: frameWidth, height: min(frameWidth * 1.4, availableHeight * 0.75))
                        .overlay(
                            ScanCornerMarkers()
                        )
                }
                
                // Instruction text - with dark capsule background
                Text("Position the invoice inside the frame")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.bottom, 40) // Extra padding below text
            }
        }
    }
    
    /// Corner markers for scan frame
    struct ScanCornerMarkers: View {
        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Top-left corner
                    CornerMark()
                        .position(x: 15, y: 15)
                    
                    // Top-right corner
                    CornerMark(rotation: 90)
                        .position(x: geometry.size.width - 15, y: 15)
                    
                    // Bottom-left corner
                    CornerMark(rotation: 270)
                        .position(x: 15, y: geometry.size.height - 15)
                    
                    // Bottom-right corner
                    CornerMark(rotation: 180)
                        .position(x: geometry.size.width - 15, y: geometry.size.height - 15)
                }
            }
        }
    }
    
    /// Individual corner mark
    struct CornerMark: View {
        var rotation: Double = 0
        
        var body: some View {
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 15))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 15, y: 0))
                }
                .stroke(Color.white, lineWidth: 2)
                .rotationEffect(.degrees(rotation))
            }
            .frame(width: 30, height: 30)
        }
    }
    
    // MARK: - Actions
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        self.errorMessage = "Camera permission is required to scan invoices"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera permission is required. Please enable it in Settings"
        @unknown default:
            errorMessage = "Unknown camera permission error"
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        
        scanner.scanInvoice(image)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isProcessing = false
                
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    errorMessage = "Failed to process image: \(error.localizedDescription)"
                }
            }, receiveValue: { invoiceData in
                self.extractedInvoiceData = invoiceData
                if hasMinimumRequiredData(invoiceData) {
                    self.showPreviewSheet = true
                } else {
                    self.showingAddInvoice = true
                }
            })
            .store(in: &CancellationTokenBag.shared.tokens)
    }
    
    private func cleanupAfterPreview() {
        extractedInvoiceData = nil
        capturedImage = nil
        showPreviewSheet = false
    }
    
    private func createScannedData(from data: InvoiceData) -> ScannedInvoiceData {
        var scannedData = ScannedInvoiceData(rawData: data.rawText ?? "")
        
        if data.title != "Scanned Invoice" {
            scannedData.title = data.title
        }
        scannedData.description = data.sender
        scannedData.amount = data.amount
        scannedData.dueDate = data.dueDate
        scannedData.barcode = data.barcode
        scannedData.qrData = data.qrData
        
        return scannedData
    }
    
    private func hasMinimumRequiredData(_ data: InvoiceData) -> Bool {
        return data.amount != nil &&
               (data.dueDate != nil || data.issueDate != nil) &&
               !data.title.isEmpty
    }
}

/// A dedicated camera handling view that doesn't attempt to add any UI elements
struct CameraSessionView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var flashOn: Bool
    @Binding var errorMessage: String?
    
    func makeUIViewController(context: Context) -> CameraSessionViewController {
        let controller = CameraSessionViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraSessionViewController, context: Context) {
        uiViewController.setFlashEnabled(flashOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraSessionDelegate {
        var parent: CameraSessionView
        
        init(_ parent: CameraSessionView) {
            self.parent = parent
        }
        
        func cameraSession(_ session: CameraSessionViewController, didCaptureImage image: UIImage?) {
            parent.capturedImage = image
        }
        
        func cameraSession(_ session: CameraSessionViewController, didFailWithError error: Error) {
            parent.errorMessage = error.localizedDescription
        }
    }
}

protocol CameraSessionDelegate: AnyObject {
    func cameraSession(_ session: CameraSessionViewController, didCaptureImage image: UIImage?)
    func cameraSession(_ session: CameraSessionViewController, didFailWithError error: Error)
}

class CameraSessionViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    weak var delegate: CameraSessionDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    private var flashEnabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        
        // Add tap gesture to capture photo when tapping on the screen
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap() {
        capturePhoto()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            delegate?.cameraSession(self, didFailWithError: NSError(domain: "CameraError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find back camera"]))
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                delegate?.cameraSession(self, didFailWithError: NSError(domain: "CameraError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not add camera input"]))
                return
            }
            
            photoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.layer.bounds
                view.layer.addSublayer(previewLayer)
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.captureSession.startRunning()
                }
            } else {
                delegate?.cameraSession(self, didFailWithError: NSError(domain: "CameraError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not add photo output"]))
            }
        } catch {
            delegate?.cameraSession(self, didFailWithError: error)
        }
    }
    
    func setFlashEnabled(_ enabled: Bool) {
        flashEnabled = enabled
    }
    
    func capturePhoto() {
        guard captureSession.isRunning else {
            delegate?.cameraSession(self, didFailWithError: NSError(domain: "CameraError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Camera session not running"]))
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashEnabled ? .on : .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            delegate?.cameraSession(self, didFailWithError: error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            delegate?.cameraSession(self, didFailWithError: NSError(domain: "CameraError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to process captured image"]))
            return
        }
        
        delegate?.cameraSession(self, didCaptureImage: image)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    deinit {
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
}



// MARK: - Sub-Views

struct ScanningModeView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isScanning: Bool
    @Binding var errorMessage: String?
    @Binding var flashOn: Bool
    var isProcessing: Bool
    
    var body: some View {
        ZStack {
            // Camera view
            EnhancedCameraView(
                capturedImage: $capturedImage,
                isScanning: $isScanning,
                errorMessage: $errorMessage,
                flashOn: $flashOn
            )
            .edgesIgnoringSafeArea(.all)
            
            // Overlay content
            VStack {
                Spacer()
                
                // Scan frame
                CleanScannerView()
                    .frame(width: 280, height: 400)
                
                Spacer()
                
                // Controls
                ScanControlsView(
                    isScanning: $isScanning,
                    flashOn: $flashOn
                )
            }
            
            // Processing overlay
            if isProcessing {
                ProcessingOverlayView()
            }
        }
    }
}

struct ScanControlsView: View {
    @Binding var isScanning: Bool
    @Binding var flashOn: Bool
    
    var body: some View {
        HStack {
            // Cancel button
            Button(action: {
                isScanning = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
            
            Spacer()
            
            // Capture button
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("TakePhoto"), object: nil)
            }) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            .frame(width: 80, height: 80)
                    )
            }
            .accessibility(label: Text("Capture Image"))
            
            Spacer()
            
            // Flash button
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

struct ProcessingOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Processing invoice...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

struct WelcomeModeView: View {
    var checkCameraPermission: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?
    var onPhotoSelected: (PhotosPickerItem) -> Void
    @Binding var showingAddInvoice: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Scan Invoice")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Position the invoice within the camera frame.\nThe app will automatically detect dates, amounts, and other details.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Camera scan button
            Button(action: checkCameraPermission) {
                HStack {
                    Image(systemName: "camera")
                    Text("Start Scanning")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.top)
            
            // Photo picker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                    Text("Select from Photos")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                if let newItem = newItem {
                    onPhotoSelected(newItem)
                }
            }
            
            // Manual entry option
            Button(action: {
                showingAddInvoice = true
            }) {
                Text("Enter Manually")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .padding()
    }
}

// MARK: - Invoice Data Preview View

struct InvoiceDataPreviewView: View {
    let invoiceData: InvoiceData
    let capturedImage: UIImage?
    let onAddInvoice: (Invoice) -> Void
    let onCancel: () -> Void
    
    @State private var editedTitle: String
    @State private var editedAmount: Double
    @State private var editedDueDate: Date
    @State private var editedCurrency: Currency
    
    // Format for display
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    // Initialize with invoice data and captured image
    init(
        invoiceData: InvoiceData,
        capturedImage: UIImage?,
        onAddInvoice: @escaping (Invoice) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.invoiceData = invoiceData
        self.capturedImage = capturedImage
        self.onAddInvoice = onAddInvoice
        self.onCancel = onCancel
        
        _editedTitle = State(initialValue: invoiceData.title)
        _editedAmount = State(initialValue: invoiceData.amount ?? 0.0)
        _editedDueDate = State(initialValue: invoiceData.dueDate ?? Date(timeIntervalSinceNow: 30 * 24 * 60 * 60))
        _editedCurrency = State(initialValue: invoiceData.currency ?? .chf)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invoice Details")) {
                    TextField("Title", text: $editedTitle)
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Amount", value: $editedAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Show formatted amount with currency
                    HStack {
                        Text("Currency")
                        Spacer()
                        Text(editedCurrency.formatAmount(editedAmount))
                            .foregroundColor(.secondary)
                    }
                    
                    // Currency picker with current styling
                    CurrencyPicker(selectedCurrency: $editedCurrency)
                    
                    DatePicker("Due Date", selection: $editedDueDate, displayedComponents: .date)
                }
                
                Section(header: Text("Extracted Information")) {
                    if let issueDate = invoiceData.issueDate {
                        DetailRow(key: "Issue Date", value: dateFormatter.string(from: issueDate))
                    }
                    
                    if let invoiceNumber = invoiceData.invoiceNumber {
                        DetailRow(key: "Invoice #", value: invoiceNumber)
                    }
                    
                    if let sender = invoiceData.sender {
                        DetailRow(key: "From", value: sender)
                    }
                    
                    if let recipient = invoiceData.recipient {
                        DetailRow(key: "To", value: recipient)
                    }
                    
                    if let paymentInfo = invoiceData.paymentInfo {
                        DetailRow(key: "Payment", value: paymentInfo)
                    }
                }
                
                if let image = capturedImage {
                    Section(header: Text("Scanned Image")) {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Invoice Preview")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        // Create the invoice with edited data
                        var invoice = invoiceData.toInvoice()
                        invoice.title = editedTitle
                        invoice.amount = editedAmount
                        invoice.dueDate = editedDueDate
                        
                        onAddInvoice(invoice)
                    }
                }
            }
        }
    }
}
