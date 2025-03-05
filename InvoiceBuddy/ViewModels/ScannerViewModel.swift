//
//  ScannerViewModel.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/ViewModels/ScannerViewModel.swift
import Foundation
import Combine
import UIKit

class ScannerViewModel: ObservableObject {
    @Published var scannedData: ScannedInvoiceData?
    @Published var isScanning = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let scanningService: ScanningServiceProtocol
    private let invoiceService: InvoiceService
    private var cancellables = Set<AnyCancellable>()
    
    init(scanningService: ScanningServiceProtocol, invoiceService: InvoiceService) {
        self.scanningService = scanningService
        self.invoiceService = invoiceService
    }
    
    func scanImage(_ image: UIImage) {
        isLoading = true
        errorMessage = nil
        
        scanningService.comprehensiveScan(image)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] data in
                self?.scannedData = data
            }
            .store(in: &cancellables)
    }
    
    func saveScannedInvoice(_ invoice: Invoice) {
        isLoading = true
        errorMessage = nil
        
        invoiceService.saveInvoice(invoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.scannedData = nil
                    self?.isScanning = false
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func createInvoiceFromScannedData() -> Invoice? {
        guard let data = scannedData else { return nil }
        
        let title = data.title ?? "Scanned Invoice"
        let description = data.description ?? ""
        let amount = data.amount ?? 0.0
        let dueDate = data.dueDate ?? Date().addingTimeInterval(60*60*24*7) // Default to 7 days from now
        
        return Invoice(
            title: title,
            description: description,
            amount: amount,
            dueDate: dueDate,
            status: .pending,
            barcode: data.barcode,
            qrData: data.qrData
        )
    }
    
    func resetScan() {
        scannedData = nil
        isScanning = false
        errorMessage = nil
    }
    
    func getAvailableCameras() -> [AVCaptureDevice] {
        return scanningService.getAvailableCameras()
    }
    
    func createCaptureSession() -> AVCaptureSession? {
        return scanningService.createCaptureSession()
    }
}