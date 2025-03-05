// Path: InvoiceBuddy/Services/Protocols/ScanningServiceProtocol.swift
import Foundation
import Combine
import UIKit
import AVFoundation

protocol ScanningServiceProtocol {
    func scanImage(_ image: UIImage) -> AnyPublisher<ScannedInvoiceData?, Error>
    func performOCROnImage(_ image: UIImage) -> AnyPublisher<String?, Error>
    func comprehensiveScan(_ image: UIImage) -> AnyPublisher<ScannedInvoiceData?, Error>
    func getAvailableCameras() -> [AVCaptureDevice]
    func createCaptureSession() -> AVCaptureSession?
}
