// ImprovedScannerView.swift
import SwiftUI
import AVFoundation
import Vision
import Combine
import PhotosUI

struct ImprovedScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var isScanning = false
    @State private var capturedImage: UIImage?
    @State private var extractedInvoiceData: InvoiceData?
    @State private var showingAddInvoice = false
    @State private var isProcessing = false
    @State private var flashOn = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPreviewSheet = false
    
    // For photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    private let scanner = EnhancedInvoiceScanner()
    
    var body: some View {
        mainNavigationView
    }
    
    // MARK: - Main View Components
    
    // The main navigation view containing everything
    private var mainNavigationView: some View {
        NavigationView {
            mainContent
                .navigationTitle("Invoice Scanner")
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
                            onAddInvoice: handleAddInvoice,
                            onCancel: handleCancelPreview
                        )
                    }
                }
                .sheet(isPresented: $showingAddInvoice) {
                    addInvoiceView
                }
                .alert(isPresented: $showError) {
                    Alert(
                        title: Text("Scanning Error"),
                        message: Text(errorMessage ?? "Unknown error occurred"),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
    }
    
    // The main content switching between scanning and welcome screens
    private var mainContent: some View {
        VStack {
            if isScanning {
                scanningView
            } else {
                welcomeView
            }
        }
    }
    
    // View that is shown when adding an invoice from scanned data
    private var addInvoiceView: some View {
        Group {
            if let data = extractedInvoiceData {
                // Only pass the rawData parameter since that's the only one accepted
                AddInvoiceView(prefillData: ScannedInvoiceData(
                    rawData: data.rawText ?? ""
                    // No other parameters are accepted by your initializer
                ))
            } else {
                AddInvoiceView()
            }
        }
    }

    
    // MARK: - Scanning UI
    
    // Scanning view when camera is active
    private var scanningView: some View {
        ZStack {
            CustomCameraView(
                capturedImage: $capturedImage,
                isScanning: $isScanning,
                errorMessage: $errorMessage,
                flashOn: $flashOn
            )
            .edgesIgnoringSafeArea(.all)
            
            scanningOverlay
            
            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
    }
    
    // Overlay controls for scanning
    private var scanningOverlay: some View {
        VStack {
            Spacer()
            
            // Larger scan overlay frame with guide text
            ImprovedScanFrameView()
                .frame(width: 320, height: 450)
            
            Spacer()
            
            // Camera controls row with flash toggle
            cameraControls
        }
    }
    
    // Camera control buttons
    private var cameraControls: some View {
        HStack(spacing: 50) {
            Button(action: {
                isScanning = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .shadow(radius: 2)
            
            // Prominent capture button
            Button(action: {
                // Trigger photo capture
                NotificationCenter.default.post(
                    name: NSNotification.Name("TakePhoto"),
                    object: nil
                )
            }) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 3)
                            .frame(width: 88, height: 88)
                    )
            }
            .shadow(radius: 3)
            .accessibility(label: Text("Take Photo"))
            
            // Flash toggle button
            Button(action: {
                flashOn.toggle()
            }) {
                Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .shadow(radius: 2)
        }
        .padding(.bottom, 40)
    }
    
    // Processing overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Processing invoice...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Welcome UI
    
    // Welcome screen with instructions and options
    private var welcomeView: some View {
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
            
            scanButton
            
            photoPickerButton
            
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
    
    // Button to start scanning
    private var scanButton: some View {
        Button(action: {
            checkCameraPermission()
        }) {
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
    }
    
    // Photo picker for selecting existing photos
    private var photoPickerButton: some View {
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
                loadTransferable(from: newItem)
            }
        }
    }
    
    // MARK: - Action Methods
    
    private func handleAddInvoice(_ invoice: Invoice) {
        dataManager.saveInvoice(invoice)
        extractedInvoiceData = nil
        capturedImage = nil
        showPreviewSheet = false
    }
    
    private func handleCancelPreview() {
        extractedInvoiceData = nil
        capturedImage = nil
        showPreviewSheet = false
    }
    
    // MARK: - Helper Methods
    
    private func loadTransferable(from photoItem: PhotosPickerItem) {
        photoItem.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    // Unwrap the optional data
                    if let imageData = data, let image = UIImage(data: imageData) {
                        self.capturedImage = image
                    } else {
                        self.errorMessage = "Could not create image from selected photo"
                    }
                case .failure(let error):
                    self.errorMessage = "Error loading photo: \(error.localizedDescription)"
                }
            }
        }
    }
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isScanning = true
        case .notDetermined:
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
    
    private func hasMinimumRequiredData(_ data: InvoiceData) -> Bool {
        // Check if we have enough meaningful data to show preview
        return data.amount != nil &&
               (data.dueDate != nil || data.issueDate != nil) &&
               !data.title.isEmpty
    }
}

// MARK: - Invoice Data Preview View

// Preview view for extracted invoice data
struct InvoiceDataPreviewView: View {
    let invoiceData: InvoiceData
    let capturedImage: UIImage?
    let onAddInvoice: (Invoice) -> Void
    let onCancel: () -> Void
    
    @State private var editedTitle: String
    @State private var editedAmount: Double
    @State private var editedDueDate: Date
    @State private var editedCurrency: Currency
    
    // Initialize with invoice data
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
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
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
                    
                    // Currency picker
                    CurrencyPicker(selectedCurrency: $editedCurrency)
                    
                    // Formatted amount preview
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(editedCurrency.formatAmount(editedAmount))
                            .fontWeight(.bold)
                    }
                    
                    DatePicker("Due Date", selection: $editedDueDate, displayedComponents: .date)
                }
                
                // Extracted data section
                Section(header: Text("Extracted Information")) {
                    extractedInfoSection
                }
                
                // Show the scanned image
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
                        // Create invoice with edited data
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
    
    // Extracted information section
    private var extractedInfoSection: some View {
        Group {
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
                DetailRow(key: "Payment Info", value: paymentInfo)
            }
        }
    }
}
