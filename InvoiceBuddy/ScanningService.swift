//
//  ScanningService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// ScanningService.swift
import Foundation
import Vision
import AVFoundation
import UIKit
import Combine

protocol ScanningService {
    func scanImage(_ image: UIImage) -> AnyPublisher<ScannedInvoiceData?, Error>
    func getAvailableCameras() -> [AVCaptureDevice]
    func createCaptureSession() -> AVCaptureSession?
}

class QRScanningService: ScanningService {
    
    func scanImage(_ image: UIImage) -> AnyPublisher<ScannedInvoiceData?, Error> {
        return Future<ScannedInvoiceData?, Error> { promise in
            guard let cgImage = image.cgImage else {
                promise(.failure(AppError.scanningError("Failed to get CGImage from UIImage")))
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Create a request to detect QR codes and barcodes
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    promise(.failure(AppError.scanningError("Barcode detection failed: \(error.localizedDescription)")))
                    return
                }
                
                guard let observations = request.results as? [VNBarcodeObservation], !observations.isEmpty else {
                    promise(.success(nil)) // No codes found, but not an error
                    return
                }
                
                // Process the first detected barcode
                if let observation = observations.first, let payload = observation.payloadStringValue {
                    let scannedData = ScannedInvoiceData(rawData: payload)
                    promise(.success(scannedData))
                } else {
                    promise(.success(nil))
                }
            }
            
            // Set the supported symbologies
            request.symbologies = [.QR, .code128, .EAN13, .EAN8, .PDF417]
            
            do {
                try requestHandler.perform([request])
            } catch {
                promise(.failure(AppError.scanningError("Failed to perform barcode detection: \(error.localizedDescription)")))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getAvailableCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }
    
    func createCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return nil
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                return nil
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                
                // Configure for available barcode types
                metadataOutput.metadataObjectTypes = [
                    .qr,
                    .ean8,
                    .ean13,
                    .pdf417,
                    .code128,
                    .code39,
                    .code93
                ]
                
                return captureSession
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
    
    // Additional methods to parse and interpret scanned data
    
    func extractInvoiceData(from text: String) -> ScannedInvoiceData {
        // This implementation matches what's in your ScannerView
        return ScannedInvoiceData(rawData: text)
    }
    
    // Check if text appears to be an invoice
    func textContainsInvoiceMarkers(_ text: String) -> Bool {
        let lowerText = text.lowercased()
        let invoiceMarkers = ["invoice", "bill", "payment", "due", "amount", "total", "pay", "$", "usd", "eur"]
        
        return invoiceMarkers.contains { marker in
            lowerText.contains(marker)
        }
    }
    
    // Scan for text if no barcode is detected
    func performOCROnImage(_ image: UIImage) -> AnyPublisher<String?, Error> {
        return Future<String?, Error> { promise in
            guard let cgImage = image.cgImage else {
                promise(.failure(AppError.scanningError("Failed to get CGImage for OCR")))
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    promise(.failure(AppError.scanningError("OCR failed: \(error.localizedDescription)")))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    promise(.success(nil))
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: " ")
                
                promise(.success(recognizedText.isEmpty ? nil : recognizedText))
            }
            
            // Configure the text recognition request for accurate recognition
            request.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([request])
            } catch {
                promise(.failure(AppError.scanningError("Failed to perform OCR: \(error.localizedDescription)")))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Comprehensive scan that tries barcode detection first, then OCR if needed
    func comprehensiveScan(_ image: UIImage) -> AnyPublisher<ScannedInvoiceData?, Error> {
        return scanImage(image)
            .flatMap { (scannedData: ScannedInvoiceData?) -> AnyPublisher<ScannedInvoiceData?, Error> in
                if let data = scannedData {
                    return Just(data).setFailureType(to: Error.self).eraseToAnyPublisher()
                } else {
                    // No barcode found, try OCR
                    return self.performOCROnImage(image)
                        .map { text -> ScannedInvoiceData? in
                            guard let text = text, !text.isEmpty else {
                                return nil
                            }
                            
                            // Only create invoice data if text appears to be invoice-related
                            if self.textContainsInvoiceMarkers(text) {
                                return self.extractInvoiceData(from: text)
                            } else {
                                return nil
                            }
                        }
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}