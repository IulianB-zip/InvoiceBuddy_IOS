//
//  CleanScannerView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 13.03.2025.
//


import SwiftUI
import AVFoundation
import Vision
import Combine

/// A completely redesigned scanner view that matches the reference screenshot exactly
struct CleanScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var capturedImage: UIImage?
    @State private var extractedInvoiceData: InvoiceData?
    @State private var showingAddInvoice = false
    @State private var isProcessing = false
    @State private var flashOn = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPreviewSheet = false
    
    // Scanner instance
    private let scanner = EnhancedInvoiceScanner()
    
    var body: some View {
        ZStack {
            // Camera view that fills the screen
            CameraSessionView(
                capturedImage: $capturedImage,
                flashOn: $flashOn,
                errorMessage: $errorMessage
            )
            .edgesIgnoringSafeArea(.all)
            
            // Frame for scanning with transparent background
            VStack(spacing: 0) {
                // Background overlay to darken the area outside the scan frame
                ZStack {
                    // Full-screen semi-transparent overlay
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    // Clear rectangular hole for the document
                    Rectangle()
                        .frame(width: 280, height: 400)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                
                // White border around scan area with corner indicators
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 280, height: 400)
                    .overlay(
                        ScanCornerMarkers()
                    )
                
                // Caption area - positioned ABOVE the tab bar
                ZStack {
                    // Black background with rounded corners
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 36)
                        .padding(.horizontal, 40)
                    
                    // Text inside the capsule
                    Text("Position the invoice inside the frame")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 16)
                .padding(.bottom, 60) // Important: Add extra padding to ensure it doesn't overlap with tab bar
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
        .onAppear {
            // Check camera permission when view appears
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
    
    // MARK: - Scan Corner Markers
    
    struct ScanCornerMarkers: View {
        var body: some View {
            ZStack {
                // Top-left corner
                CornerMark().position(x: 15, y: 15)
                
                // Top-right corner
                CornerMark(rotation: 90).position(x: 265, y: 15)
                
                // Bottom-left corner
                CornerMark(rotation: 270).position(x: 15, y: 385)
                
                // Bottom-right corner
                CornerMark(rotation: 180).position(x: 265, y: 385)
            }
            .frame(width: 280, height: 400)
        }
    }
    
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
            // Already authorized
            break
        case .notDetermined:
            // Request permission
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


// MARK: - Invoice Scan Frame

struct InvoiceScanFrame: View {
    var body: some View {
        ZStack {
            // Transparent cutout
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 280, height: 400)
            
            // Corner markers
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Top-left corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 20))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 20, y: 0))
                }
                .stroke(Color.white, lineWidth: 3)
                .offset(x: width/2 - 140, y: height/2 - 200)
                
                // Top-right corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 20, y: 0))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                }
                .stroke(Color.white, lineWidth: 3)
                .offset(x: width/2 + 120, y: height/2 - 200)
                
                // Bottom-left corner
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 20))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                }
                .stroke(Color.white, lineWidth: 3)
                .offset(x: width/2 - 140, y: height/2 + 180)
                
                // Bottom-right corner
                Path { path in
                    path.move(to: CGPoint(x: 20, y: 0))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                    path.addLine(to: CGPoint(x: 0, y: 20))
                }
                .stroke(Color.white, lineWidth: 3)
                .offset(x: width/2 + 120, y: height/2 + 180)
            }
        }
    }
}
