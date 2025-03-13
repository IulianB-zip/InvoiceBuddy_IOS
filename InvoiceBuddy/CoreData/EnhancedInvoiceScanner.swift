//
//  EnhancedInvoiceScanner.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 07.03.2025.
//

import SwiftUI
import AVFoundation
import Vision
import Combine

// Structure to represent line items in an invoice
struct InvoiceLineItem {
    var description: String
    var amount: Double
    var quantity: Double?
    var unitPrice: Double?
    var vatRate: Double?
}

// InvoiceData structure to hold extracted information
struct InvoiceData {
    var rawText: String?
    var qrData: String?
    var barcode: String?
    var title: String = "Scanned Invoice"
    var invoiceNumber: String?
    var amount: Double?
    var issueDate: Date?
    var dueDate: Date?
    var recipient: String?
    var sender: String?
    var paymentInfo: String?
    var currency: Currency?
    var paymentDays: Int?
    var vatAmount: Double?
    var vatRate: Double?
    var lineItems: [InvoiceLineItem]?
    
    // Initialize with default values
    init() {
        self.title = "Scanned Invoice"
        self.currency = .chf
        self.lineItems = []
    }
    
    // Convert to Invoice model
    func toInvoice() -> Invoice {
        let newInvoice = Invoice(
            id: UUID(),
            title: self.title,
            description: self.sender ?? "",
            amount: self.amount ?? 0.0,
            dueDate: self.dueDate ?? Date(timeIntervalSinceNow: 30 * 24 * 60 * 60), // Default to 30 days
            status: .pending,
            paymentMethod: nil,
            reminderDate: Calendar.current.date(byAdding: .day, value: -3, to: self.dueDate ?? Date(timeIntervalSinceNow: 30 * 24 * 60 * 60)),
            barcode: self.barcode,
            qrData: self.qrData,
            notes: generateNotes(),
            priority: 0,
            isPaid: false,
            paymentDate: nil,
            associatedCardId: nil
        )
        return newInvoice
    }
    
    // Generate notes from available data
    private func generateNotes() -> String? {
        var notes = [String]()
        
        if let issueDate = self.issueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            notes.append("Issue Date: \(formatter.string(from: issueDate))")
        }
        
        if let invoiceNumber = self.invoiceNumber {
            notes.append("Invoice Number: \(invoiceNumber)")
        }
        
        if let recipient = self.recipient {
            notes.append("Recipient: \(recipient)")
        }
        
        if let sender = self.sender {
            notes.append("Sender: \(sender)")
        }
        
        if let paymentInfo = self.paymentInfo {
            notes.append("Payment Info: \(paymentInfo)")
        }
        
        if let vatAmount = self.vatAmount {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            let amountStr = formatter.string(from: NSNumber(value: vatAmount)) ?? "\(vatAmount)"
            notes.append("VAT Amount: \(amountStr)")
        }
        
        if let lineItems = self.lineItems, !lineItems.isEmpty {
            notes.append("\nLine Items:")
            for (index, item) in lineItems.enumerated() {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 2
                let amountStr = formatter.string(from: NSNumber(value: item.amount)) ?? "\(item.amount)"
                notes.append("  \(index+1). \(item.description): \(amountStr)")
            }
        }
        
        if let rawText = self.rawText, notes.isEmpty {
            // If no structured data, use beginning of raw text
            let previewLength = min(150, rawText.count)
            let textPreview = String(rawText.prefix(previewLength))
            return "Scanned content preview: \(textPreview)..."
        }
        
        return notes.isEmpty ? nil : notes.joined(separator: "\n")
    }
}



class EnhancedInvoiceScanner {
    
    // MARK: - Date Detection Constants
    
    private let issueDateKeywords = [
        "Rechnungs-Datum", "Invoice Date", "Issue Date", "Datum", "Date",
        "Issued on", "Issued", "vom", "date d'émission", "fecha de emisión"
    ]
    
    private let dueDateKeywords = [
        "Due Date", "Payment Due", "Zahlbar bis", "fällig am", "fällig", "due by",
        "zahlbar innerhalb", "payable within", "due in", "payment terms",
        "Zahlungsziel", "Zahlbar", "Zahlung", "date d'échéance", "fecha de vencimiento"
    ]
    
    private let dateFormats = [
        "dd.MM.yyyy", "MM.dd.yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy",
        "dd.MM.yy", "MM.dd.yy", "yy-MM-dd", "dd MMM yyyy", "MMM dd, yyyy",
        "yyyy/MM/dd", "dd-MM-yyyy"
    ]
    
    // MARK: - Comprehensive Scan Method
    
    func scanInvoice(_ image: UIImage) -> AnyPublisher<InvoiceData, Error> {
        return extractText(from: image)
            .flatMap { extractedText -> AnyPublisher<InvoiceData, Error> in
                // Create basic invoice data
                let invoiceData = self.parseInvoiceData(from: extractedText)
                
                // If there's a QR code, extract it too
                return self.scanQRAndBarcodes(image)
                    .map { scannedCodes -> InvoiceData in
                        var enhancedData = invoiceData
                        enhancedData.qrData = scannedCodes.qrData
                        enhancedData.barcode = scannedCodes.barcode
                        
                        // Try to extract IBAN/Payment info from QR if available
                        if let qrText = scannedCodes.qrData {
                            enhancedData = self.enhanceWithQRData(qrText, data: enhancedData)
                        }
                        
                        return enhancedData
                    }
                    .catch { _ in
                        // If QR scan fails, just return the text-based data
                        return Just(invoiceData)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - OCR Text Extraction
    
    private func extractText(from image: UIImage) -> AnyPublisher<String, Error> {
        return Future<String, Error> { promise in
            guard let cgImage = image.cgImage else {
                promise(.failure(NSError(domain: "InvoiceScanner", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage"])))
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    promise(.success(""))
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                promise(.success(recognizedText))
            }
            
            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - QR and Barcode Scanning
    
    private func scanQRAndBarcodes(_ image: UIImage) -> AnyPublisher<(qrData: String?, barcode: String?), Error> {
        return Future<(qrData: String?, barcode: String?), Error> { promise in
            guard let cgImage = image.cgImage else {
                promise(.failure(NSError(domain: "InvoiceScanner", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from UIImage"])))
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let observations = request.results as? [VNBarcodeObservation] else {
                    promise(.success((qrData: nil, barcode: nil)))
                    return
                }
                
                var qrCode: String? = nil
                var barcode: String? = nil
                
                for observation in observations {
                    guard let payload = observation.payloadStringValue else { continue }
                    
                    switch observation.symbology {
                    case .QR:
                        qrCode = payload
                    case .code128, .EAN13, .EAN8, .UPCE, .code39, .ITF14:
                        barcode = payload
                    default:
                        break
                    }
                }
                
                promise(.success((qrData: qrCode, barcode: barcode)))
            }
            
            // Configure for barcode detection
            request.symbologies = [.QR, .code128, .EAN13, .EAN8, .UPCE, .code39, .ITF14, .PDF417]
            
            do {
                try requestHandler.perform([request])
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Invoice Data Parsing
    
    private func parseInvoiceData(from text: String) -> InvoiceData {
        let lines = text.components(separatedBy: .newlines)
        
        var invoiceData = InvoiceData()
        invoiceData.rawText = text
        
        // Extract invoice title (usually one of the first prominent words)
        invoiceData.title = extractInvoiceTitle(from: lines)
        
        // Extract amount (using regex patterns)
        invoiceData.amount = extractAmount(from: text)
        
        // Extract dates
        let (issueDate, dueDate) = extractDates(from: lines)
        invoiceData.issueDate = issueDate
        invoiceData.dueDate = dueDate
        
        // Try to auto-calculate due date if issue date is found but due date is not
        if invoiceData.dueDate == nil && invoiceData.issueDate != nil {
            // First try to extract payment days
            let paymentDays = extractPaymentDays(from: text)
            invoiceData.paymentDays = paymentDays
            
            if let days = paymentDays {
                invoiceData.dueDate = Calendar.current.date(byAdding: .day, value: days, to: invoiceData.issueDate!)
            } else {
                // Fall back to standard calculation
                invoiceData.dueDate = calculateDueDate(from: text, issueDate: invoiceData.issueDate!)
            }
        }
        
        // Extract invoice number
        invoiceData.invoiceNumber = extractInvoiceNumber(from: lines)
        
        // Extract recipient and sender
        let (recipient, sender) = extractParties(from: lines)
        invoiceData.recipient = recipient
        invoiceData.sender = sender
        
        // Extract payment details
        invoiceData.paymentInfo = extractPaymentInfo(from: text)
        
        // Extract VAT information
        let (vatAmount, vatRate) = extractVATInformation(from: text)
        invoiceData.vatAmount = vatAmount
        invoiceData.vatRate = vatRate
        
        // Extract currency
        invoiceData.currency = extractCurrency(from: text)
        
        // Extract line items
        invoiceData.lineItems = extractLineItems(from: text)
        
        // Apply special enhancements for Swiss medical invoices
        enhanceForSwissMedicalInvoice(data: &invoiceData, text: text)
        
        return invoiceData
    }
    
    // MARK: - Helper Methods for Data Extraction
    
    private func extractInvoiceTitle(from lines: [String]) -> String {
        // Common invoice title keywords
        let invoiceTitleKeywords = ["Rechnung", "Invoice", "Bill", "Honorar-Rechnung", "Receipt"]
        
        // First try to find lines containing invoice keywords
        for line in lines.prefix(10) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty {
                for keyword in invoiceTitleKeywords {
                    if trimmedLine.contains(keyword) && trimmedLine.count < 30 {
                        return trimmedLine
                    }
                }
            }
        }
        
        // If no invoice title found, use the first non-empty line
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLine.isEmpty && trimmedLine.count < 30 {
                return trimmedLine
            }
        }
        
        // Default title if nothing else is found
        return "Scanned Invoice"
    }
    
    private func extractAmount(from text: String) -> Double? {
        // Pattern to match amounts in format: 123.45, 1,234.56, 1 234,56 etc.
        // Also handles currency symbols like $, €, CHF
        let patterns = [
            // CHF/EUR/USD 123.45 or 123,45
            #"(CHF|EUR|USD|€|\$)\s*(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2})"#,
            
            // 123.45 CHF/EUR/USD - amount followed by currency
            #"(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2})\s*(CHF|EUR|USD|€|\$)"#,
            
            // Just numbers with decimal point
            #"(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2})"#,
            
            // Whole numbers with currency
            #"(CHF|EUR|USD|€|\$)\s*(\d+)"#,
            
            // Just whole numbers
            #"Total:?\s*(\d+)"#,
            
            // 'Gesamttotal' in Swiss invoices
            #"Gesamttotal:?\s*(CHF|EUR|USD|€|\$)?\s*(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2})"#,
            
            // 'Rechnungsbetrag' in German invoices
            #"Rechnungsbetrag:?\s*(CHF|EUR|USD|€|\$)?\s*(\d{1,3}(?:[.,\s]\d{3})*[.,]\d{2})"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    // Extract the amount part depending on the pattern
                    var amountString = ""
                    
                    if match.numberOfRanges >= 3 {
                        // Pattern with currency and amount groups
                        if let amountRange = Range(match.range(at: 2), in: text) {
                            amountString = String(text[amountRange])
                        }
                    } else if match.numberOfRanges >= 2 {
                        // Pattern with just amount group
                        if let amountRange = Range(match.range(at: 1), in: text) {
                            amountString = String(text[amountRange])
                        }
                    }
                    
                    if !amountString.isEmpty {
                        // Clean up the amount string
                        amountString = amountString.replacingOccurrences(of: " ", with: "")
                        amountString = amountString.replacingOccurrences(of: ",", with: ".")
                        
                        // Handle thousands separators
                        if amountString.contains(".") {
                            let components = amountString.components(separatedBy: ".")
                            if components.count > 2 {
                                // Multiple dots, assume last is decimal point
                                let lastComponent = components.last!
                                let mainPart = components.dropLast().joined()
                                amountString = mainPart + "." + lastComponent
                            }
                        }
                        
                        return Double(amountString)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractDates(from lines: [String]) -> (issueDate: Date?, dueDate: Date?) {
        var issueDate: Date? = nil
        var dueDate: Date? = nil
        
        for line in lines {
            // Search for issue date
            if issueDate == nil {
                for keyword in issueDateKeywords {
                    if line.contains(keyword) {
                        if let date = extractDate(from: line) {
                            issueDate = date
                            break
                        }
                    }
                }
            }
            
            // Search for due date
            if dueDate == nil {
                for keyword in dueDateKeywords {
                    if line.contains(keyword) {
                        if let date = extractDate(from: line) {
                            dueDate = date
                            break
                        }
                    }
                }
            }
            
            // Stop if both dates are found
            if issueDate != nil && dueDate != nil {
                break
            }
        }
        
        // If no specific keywords were found, try to extract any dates
        if issueDate == nil || dueDate == nil {
            var foundDates = [Date]()
            
            for line in lines {
                if let date = extractDate(from: line) {
                    foundDates.append(date)
                }
            }
            
            foundDates.sort()
            
            if foundDates.count >= 2 {
                // Assume first date is issue date and second is due date
                if issueDate == nil {
                    issueDate = foundDates[0]
                }
                
                if dueDate == nil {
                    dueDate = foundDates[1]
                }
            } else if foundDates.count == 1 {
                // If only one date is found, assume it's the issue date
                if issueDate == nil {
                    issueDate = foundDates[0]
                }
            }
        }
        
        return (issueDate, dueDate)
    }
    
    private func extractDate(from text: String) -> Date? {
        // Direct date extraction using DateFormatter
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            
            // Extract date pattern using regex
            let datePatterns = [
                #"\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4}"#, // 01.01.2023, 01/01/2023, 01-01-2023
                #"\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2}"#,    // 2023.01.01, 2023/01/01, 2023-01-01
                #"\d{1,2}\s+[A-Za-z]{3,}\s+\d{2,4}"#    // 01 Jan 2023
            ]
            
            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let nsText = text as NSString
                    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                    
                    for match in matches {
                        let dateString = nsText.substring(with: match.range)
                        if let date = formatter.date(from: dateString) {
                            // Validate the date is reasonable (not too far in the past or future)
                            if date > Calendar.current.date(byAdding: .year, value: -5, to: Date())! &&
                                date < Calendar.current.date(byAdding: .year, value: 5, to: Date())! {
                                return date
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func calculateDueDate(from text: String, issueDate: Date) -> Date? {
        // Look for payment terms indicators
        let paymentTermsPatterns = [
            #"zahlbar innerhalb von (\d+) Tagen"#,
            #"payable within (\d+) days"#,
            #"due in (\d+) days"#,
            #"Zahlungsziel: (\d+) Tage"#,
            #"zahlbar innerhalb (\d+) Tagen"#,
            #"Zahlbar innert (\d+) Tagen"#,
            #"Net (\d+)"#,
            #"(\d+) days"#,
            #"innerhalb (\d+)"#,
            #"innerhalb von (\d+) Tagen"#
        ]
        
        for pattern in paymentTermsPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsText = text as NSString
                let range = NSRange(location: 0, length: nsText.length)
                
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   match.numberOfRanges >= 2,
                   let daysRange = Range(match.range(at: 1), in: text),
                   let days = Int(text[daysRange]) {
                    // Calculate due date based on payment terms
                    return Calendar.current.date(byAdding: .day, value: days, to: issueDate)
                }
            }
        }
        
        // Default to 30 days if no specific terms found
        return Calendar.current.date(byAdding: .day, value: 30, to: issueDate)
    }
    
    private func extractInvoiceNumber(from lines: [String]) -> String? {
        let invoiceNumberKeywords = [
            "Rechnungs-Nummer", "Rechnung Nr", "Rechnung No", "Rechnungsnr", "Rechnungsnummer",
            "Invoice Number", "Invoice No", "Invoice #", "Reference", "Referenz", "Ref",
            "No", "Nummer", "Auftrag", "Beleg"
        ]
        
        for line in lines {
            for keyword in invoiceNumberKeywords {
                if line.contains(keyword) {
                    // Try to extract the invoice number after the keyword
                    if let range = line.range(of: keyword) {
                        let start = range.upperBound
                        let remaining = String(line[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Look for alphanumeric segment after any separator (colon, dash, etc.)
                        let separators = [":", "-", ".", "#", " "]
                        for separator in separators {
                            if let sepRange = remaining.range(of: separator) {
                                let afterSep = String(remaining[sepRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Extract alphanumeric part
                                if let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9\\-]+") {
                                    let nsString = afterSep as NSString
                                    if let match = regex.firstMatch(in: afterSep, range: NSRange(location: 0, length: nsString.length)) {
                                        return nsString.substring(with: match.range)
                                    }
                                }
                                
                                return afterSep.components(separatedBy: .whitespacesAndNewlines).first ?? afterSep
                            }
                        }
                        
                        // If no separator, try to extract first alphanumeric segment
                        if let regex = try? NSRegularExpression(pattern: "[A-Za-z0-9\\-]+") {
                            let nsString = remaining as NSString
                            if let match = regex.firstMatch(in: remaining, range: NSRange(location: 0, length: nsString.length)) {
                                return nsString.substring(with: match.range)
                            }
                        }
                        
                        return remaining
                    }
                }
            }
        }
        
        // Look for patterns like "No: 12345" or "Nr. 12345"
        let patterns = [
            #"No\.?\s*:?\s*([A-Za-z0-9\-]+)"#,
            #"Nr\.?\s*:?\s*([A-Za-z0-9\-]+)"#,
            #"Referenz\s*:?\s*([A-Za-z0-9\-]+)"#,
            #"Reference\s*:?\s*([A-Za-z0-9\-]+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsText = lines.joined(separator: " ") as NSString
                let range = NSRange(location: 0, length: nsText.length)
                
                if let match = regex.firstMatch(in: nsText as String, options: [], range: range),
                   match.numberOfRanges >= 2 {
                    return nsText.substring(with: match.range(at: 1))
                }
            }
        }
        
        return nil
    }
    
    private func extractParties(from lines: [String]) -> (recipient: String?, sender: String?) {
        // Keywords that might indicate recipient info
        let recipientKeywords = ["An:", "To:", "Kunde:", "Customer:", "Rechnungsadressat", "Rechnung an", "Bill to"]
        
        // Keywords that might indicate sender info
        let senderKeywords = ["Von:", "From:", "Absender:", "Sender:", "Rechnungssteller", "Praxis", "Klinik"]
        
        var recipientLines: [String] = []
        var senderLines: [String] = []
        
        var inRecipientSection = false
        var inSenderSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty {
                inRecipientSection = false
                inSenderSection = false
                continue
            }
            
            // Check if line indicates recipient
            for keyword in recipientKeywords {
                if trimmedLine.contains(keyword) {
                    inRecipientSection = true
                    inSenderSection = false
                    
                    // Extract content after keyword
                    if let range = trimmedLine.range(of: keyword) {
                        let content = String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !content.isEmpty {
                            recipientLines.append(content)
                        }
                    } else {
                        recipientLines.append(trimmedLine)
                    }
                    break
                }
            }
            
            // Check if line indicates sender
            if !inRecipientSection {
                for keyword in senderKeywords {
                    if trimmedLine.contains(keyword) {
                        inSenderSection = true
                        inRecipientSection = false
                        
                        // Extract content after keyword
                        if let range = trimmedLine.range(of: keyword) {
                            let content = String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !content.isEmpty {
                                senderLines.append(content)
                            }
                        } else {
                            senderLines.append(trimmedLine)
                        }
                        break
                    }
                }
            }
            
            // Continue collecting lines for the current section
            if inRecipientSection && !recipientLines.contains(trimmedLine) {
                recipientLines.append(trimmedLine)
            } else if inSenderSection && !senderLines.contains(trimmedLine) {
                senderLines.append(trimmedLine)
            }
            
            // Detect name patterns (Firstname Lastname)
            if !inRecipientSection && !inSenderSection {
                let namePattern = #"^[A-Z][a-z]+ [A-Z][a-z]+"#
                if let regex = try? NSRegularExpression(pattern: namePattern),
                   regex.firstMatch(in: trimmedLine, range: NSRange(location: 0, length: trimmedLine.count)) != nil {
                    
                    // Check if this looks like a recipient (person name)
                    if recipientLines.isEmpty && senderLines.count < 3 {
                        recipientLines.append(trimmedLine)
                    }
                }
            }
        }
        
        // If nothing found, try to extract any address-like content
                if recipientLines.isEmpty {
                    var addressFound = false
                    
                    for line in lines {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Look for postal code patterns
                        let postalCodePatterns = [
                            #"\b\d{4,5}\s+[A-Z][a-z]+"#,  // e.g., "8001 Zürich"
                            #"\b[A-Z]{1,2}\d{1,2}\s+\d[A-Z]{2}"# // e.g., "SW1A 1AA" (UK style)
                        ]
                        
                        for pattern in postalCodePatterns {
                            if let regex = try? NSRegularExpression(pattern: pattern),
                               regex.firstMatch(in: trimmedLine, range: NSRange(location: 0, length: trimmedLine.count)) != nil {
                                
                                // Found a postal code, check previous line for recipient
                                let lineIndex = lines.firstIndex(of: line)
                                if let index = lineIndex, index > 0 {
                                    let previousLine = lines[index - 1].trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !previousLine.isEmpty {
                                        recipientLines.append(previousLine)
                                    }
                                    recipientLines.append(trimmedLine)
                                    addressFound = true
                                    break
                                }
                            }
                        }
                        
                        if addressFound {
                            break
                        }
                    }
                }
                
                // Format the extracted information
                let recipient = recipientLines.isEmpty ? nil : recipientLines.joined(separator: ", ")
                let sender = senderLines.isEmpty ? nil : senderLines.joined(separator: ", ")
                
                return (recipient, sender)
            }
            
            private func extractPaymentInfo(from text: String) -> String? {
                let paymentInfoKeywords = [
                    "IBAN", "Konto", "Account", "Kontonummer", "Zahlung an",
                    "Zahlbar an", "Payment to", "Bank", "BIC", "SWIFT"
                ]
                
                let lines = text.components(separatedBy: .newlines)
                var paymentInfoLines: [String] = []
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    for keyword in paymentInfoKeywords {
                        if trimmedLine.contains(keyword) {
                            paymentInfoLines.append(trimmedLine)
                            break
                        }
                    }
                    
                    // Look for IBAN pattern
                    let ibanPattern = #"[A-Z]{2}\d{2}[A-Z0-9]{4}[A-Z0-9]{4}[A-Z0-9]{4}[A-Z0-9]{4}[A-Z0-9]{0,4}"#
                    if let regex = try? NSRegularExpression(pattern: ibanPattern),
                       regex.firstMatch(in: trimmedLine, range: NSRange(location: 0, length: trimmedLine.count)) != nil {
                        paymentInfoLines.append(trimmedLine)
                    }
                }
                
                return paymentInfoLines.isEmpty ? nil : paymentInfoLines.joined(separator: ", ")
            }
            
            // MARK: - QR Code Enhancement
            
            private func enhanceWithQRData(_ qrText: String, data: InvoiceData) -> InvoiceData {
                var enhancedData = data
                
                // Swiss QR Code format contains payment data
                if qrText.contains("SPC") {
                    // Extract IBAN if present
                    let ibanPattern = #"[A-Z]{2}\d{2}[A-Z0-9]{4}[A-Z0-9]{4}[A-Z0-9]{4}[A-Z0-9]{4}[A-Z0-9]{0,4}"#
                    if let regex = try? NSRegularExpression(pattern: ibanPattern),
                       let match = regex.firstMatch(in: qrText, range: NSRange(location: 0, length: qrText.count)) {
                        let nsText = qrText as NSString
                        let iban = nsText.substring(with: match.range)
                        
                        if enhancedData.paymentInfo == nil {
                            enhancedData.paymentInfo = "IBAN: \(iban)"
                        } else if !enhancedData.paymentInfo!.contains(iban) {
                            enhancedData.paymentInfo = enhancedData.paymentInfo! + ", IBAN: \(iban)"
                        }
                    }
                    
                    // Extract amount if not already detected
                    if enhancedData.amount == nil {
                        let amountPattern = #"(?<=Amount:)[0-9.,]+"#
                        if let regex = try? NSRegularExpression(pattern: amountPattern),
                           let match = regex.firstMatch(in: qrText, range: NSRange(location: 0, length: qrText.count)) {
                            let nsText = qrText as NSString
                            let amountString = nsText.substring(with: match.range)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: ",", with: ".")
                            
                            enhancedData.amount = Double(amountString)
                        }
                    }
                }
                
                return enhancedData
            }
            
            // MARK: - Additional Parsing Methods
    private func extractVATInformation(from text: String) -> (amount: Double?, rate: Double?) {
        var vatAmount: Double? = nil
        var vatRate: Double? = nil
        
        // Common VAT patterns
        let vatPatterns = [
            // VAT amount patterns
            #"(VAT|MWST|USt|TVA|IVA|BTW)[\s:]*(\d+[\.,]\d{2})"#,
            #"(Mehrwertsteuer|Value Added Tax)[\s:]*(\d+[\.,]\d{2})"#,
            #"(VAT|MWST|USt|TVA|IVA|BTW)[\s:]*\((\d+)[\.,%]*\)[\s:]*(\d+[\.,]\d{2})"#,
            
            // VAT rate patterns
            #"(VAT|MWST|USt|TVA|IVA|BTW)[\s:]*(\d+[\.,%]*)"#,
            #"(\d+[\.,%]*)[\s]*(VAT|MWST|USt|TVA|IVA|BTW)"#,
            #"(Mehrwertsteuer|Value Added Tax)[\s:]*(\d+[\.,%]*)"#
        ]
        
        for pattern in vatPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if match.numberOfRanges >= 3 {
                        // Pattern with VAT rate and possibly amount
                        if let rateRange = Range(match.range(at: 2), in: text) {
                            let rateString = String(text[rateRange])
                                .replacingOccurrences(of: ",", with: ".")
                                .replacingOccurrences(of: "%", with: "")
                            
                            if let rate = Double(rateString) {
                                vatRate = rate
                                
                                // If pattern includes amount (index 3)
                                if match.numberOfRanges >= 4, let amountRange = Range(match.range(at: 3), in: text) {
                                    let amountString = String(text[amountRange])
                                        .replacingOccurrences(of: ",", with: ".")
                                    
                                    if let amount = Double(amountString) {
                                        vatAmount = amount
                                    }
                                }
                            }
                        }
                    } else if match.numberOfRanges >= 2 {
                        // Simple pattern with just one number - could be amount or rate
                        if let valueRange = Range(match.range(at: 1), in: text) {
                            let valueString = String(text[valueRange])
                                .replacingOccurrences(of: ",", with: ".")
                                .replacingOccurrences(of: "%", with: "")
                            
                            if let value = Double(valueString) {
                                // If value is small (0-99), it's likely a rate
                                if value < 100 {
                                    vatRate = value
                                } else {
                                    // Otherwise assume it's an amount
                                    vatAmount = value
                                }
                            }
                        }
                    }
                }
                
                // If we found both, we can stop
                if vatRate != nil && vatAmount != nil {
                    break
                }
            }
        }
        
        // Extract invoice amount to help calculate VAT if missing
        let invoiceAmount = extractAmount(from: text)
        
        // If we have amount but not rate (or vice versa), try to calculate the other
        if vatAmount != nil && vatRate == nil && invoiceAmount != nil {
            // Typical VAT rates to check
            let typicalRates = [7.7, 8.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0, 25.0]
            
            for rate in typicalRates {
                let calculatedAmount = (invoiceAmount! * rate) / 100.0
                // Allow small rounding difference
                if abs(calculatedAmount - (vatAmount ?? 0)) < 0.1 {
                    vatRate = rate
                    break
                }
            }
        } else if vatRate != nil && vatAmount == nil && invoiceAmount != nil {
            // Calculate VAT amount from rate
            vatAmount = (invoiceAmount! * (vatRate ?? 0)) / 100.0
        }
        
        return (vatAmount, vatRate)
    }

            private func extractLineItems(from text: String) -> [InvoiceLineItem]? {
                var lineItems = [InvoiceLineItem]()
                let lines = text.components(separatedBy: .newlines)
                
                // Common patterns for line items
                // Look for lines with description followed by numbers (quantity, price, amount)
                let lineItemPatterns = [
                    #"(.{3,30})\s+(\d+)[\s.x]+(\d+[\.,]\d{2})\s+(\d+[\.,]\d{2})"#,  // Description, quantity, unit price, amount
                    #"(.{3,30})\s+(\d+[\.,]\d{2})"#,  // Description, amount
                    #"(\d+\.?\d*)\s*x\s*(.{3,30})\s+(\d+[\.,]\d{2})"#  // Quantity x Description, amount
                ]
                
                // Try to identify sections that might contain line items
                var inItemsSection = false
                var itemsBlockStart = 0
                var itemsBlockEnd = lines.count
                
                // Look for section headers
                for (index, line) in lines.enumerated() {
                    let lowercaseLine = line.lowercased()
                    
                    if lowercaseLine.contains("artikel") ||
                       lowercaseLine.contains("position") ||
                       lowercaseLine.contains("items") ||
                       lowercaseLine.contains("leistung") ||
                       (lowercaseLine.contains("beschreibung") && lowercaseLine.contains("betrag")) {
                        inItemsSection = true
                        itemsBlockStart = index + 1
                    } else if inItemsSection && (
                        lowercaseLine.contains("total") ||
                        lowercaseLine.contains("summe") ||
                        lowercaseLine.contains("zwischensumme") ||
                        lowercaseLine.contains("gesamtbetrag")
                    ) {
                        itemsBlockEnd = index
                        break
                    }
                }
                
                // If we've identified a section, focus on that
                let relevantLines = inItemsSection ?
                    Array(lines[itemsBlockStart..<min(itemsBlockEnd, lines.count)]) :
                    lines
                
                // Try to extract line items
                for line in relevantLines {
                    if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continue
                    }
                    
                    for pattern in lineItemPatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern) {
                            let nsLine = line as NSString
                            let range = NSRange(location: 0, length: nsLine.length)
                            
                            if let match = regex.firstMatch(in: line, options: [], range: range) {
                                if match.numberOfRanges >= 5 {
                                    // Full pattern: description, quantity, unit price, amount
                                    let description = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    let quantityStr = nsLine.substring(with: match.range(at: 2)).replacingOccurrences(of: ",", with: ".")
                                    let unitPriceStr = nsLine.substring(with: match.range(at: 3)).replacingOccurrences(of: ",", with: ".")
                                    let amountStr = nsLine.substring(with: match.range(at: 4)).replacingOccurrences(of: ",", with: ".")
                                    
                                    if let quantity = Double(quantityStr),
                                       let unitPrice = Double(unitPriceStr),
                                       let amount = Double(amountStr) {
                                        let item = InvoiceLineItem(
                                            description: description,
                                            amount: amount,
                                            quantity: quantity,
                                            unitPrice: unitPrice,
                                            vatRate: nil
                                        )
                                        lineItems.append(item)
                                        break // Move to next line
                                    }
                                } else if match.numberOfRanges >= 3 {
                                    // Pattern with description and amount or quantity x description and amount
                                    let description = nsLine.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                                    let amountStr = nsLine.substring(with: match.range(at: 2)).replacingOccurrences(of: ",", with: ".")
                                    
                                    if let amount = Double(amountStr) {
                                        let item = InvoiceLineItem(
                                            description: description,
                                            amount: amount,
                                            quantity: nil,
                                            unitPrice: nil,
                                            vatRate: nil
                                        )
                                        lineItems.append(item)
                                        break // Move to next line
                                    }
                                }
                            }
                        }
                    }
                }
                
                return lineItems.isEmpty ? nil : lineItems
            }

            private func extractCurrency(from text: String) -> Currency? {
                // Look for currency symbols or codes
                let currencyPatterns = [
                    "CHF": Currency.chf,
                    "€": Currency.eur,
                    "EUR": Currency.eur,
                    "$": Currency.usd,
                    "USD": Currency.usd,
                    "£": Currency.gbp,
                    "GBP": Currency.gbp,
                    "¥": Currency.jpy,
                    "JPY": Currency.jpy,
                    "RON": Currency.ron,
                    "CNY": Currency.cny,
                    "CAD": Currency.cad,
                    "AUD": Currency.aud,
                    "BRL": Currency.brl,
                    "MXN": Currency.mxn
                ]
                
                for (pattern, currency) in currencyPatterns {
                    if text.contains(pattern) {
                        return currency
                    }
                }
                
                // Default for Swiss invoices
                return .chf
            }
            
            // MARK: - Advanced Scanning Features
            
            // Extract payment days from text
            private func extractPaymentDays(from text: String) -> Int? {
                let patterns = [
                    #"zahlbar innerhalb (\d+) Tage"#,
                    #"zahlbar innerhalb von (\d+) Tagen"#,
                    #"innerhalb von (\d+) Tagen"#,
                    #"Zahlungsziel:?\s*(\d+) Tage"#,
                    #"payable within (\d+) days"#,
                    #"Net (\d+)"#,
                    #"due in (\d+) days"#,
                    #"(\d+) days net"#,
                    #"(\d+) Tage netto"#,
                    #"(\d+) Tage Valuta"#,
                ]
                
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                        let nsText = text as NSString
                        let range = NSRange(location: 0, length: nsText.length)
                        
                        if let match = regex.firstMatch(in: text, options: [], range: range),
                           match.numberOfRanges >= 2,
                           let valueRange = Range(match.range(at: 1), in: text),
                           let days = Int(text[valueRange]) {
                            return days
                        }
                    }
                }
                
                return nil
            }
            
            // Extract invoice language to improve other extraction
            private func detectLanguage(from text: String) -> String? {
                // Simple language detection based on keyword frequency
                let germanKeywords = ["Rechnung", "Betrag", "Zahlung", "Datum", "Umsatzsteuer", "Mehrwertsteuer", "Gesamt", "Lieferung", "fällig"]
                let englishKeywords = ["invoice", "amount", "payment", "date", "vat", "tax", "total", "delivery", "due"]
                let frenchKeywords = ["facture", "montant", "paiement", "date", "tva", "impôt", "total", "livraison", "échéance"]
                
                var germanCount = 0
                var englishCount = 0
                var frenchCount = 0
                
                let lowercaseText = text.lowercased()
                
                for keyword in germanKeywords {
                    if lowercaseText.contains(keyword.lowercased()) {
                        germanCount += 1
                    }
                }
                
                for keyword in englishKeywords {
                    if lowercaseText.contains(keyword) {
                        englishCount += 1
                    }
                }
                
                for keyword in frenchKeywords {
                    if lowercaseText.contains(keyword) {
                        frenchCount += 1
                    }
                }
                
                // Return the language with the most matches
                if germanCount >= englishCount && germanCount >= frenchCount {
                    return "de"
                } else if englishCount >= germanCount && englishCount >= frenchCount {
                    return "en"
                } else if frenchCount >= germanCount && frenchCount >= englishCount {
                    return "fr"
                }
                
                return nil
            }
            
            // MARK: - Enhanced Parsing for Swiss Medical Invoices
            
            private func enhanceForSwissMedicalInvoice(data: inout InvoiceData, text: String) {
                // Check if this looks like a Swiss medical invoice
                let medicalKeywords = ["Rechnung", "Honorar", "Patient", "Patientin", "Behandlung", "Praxis", "Arzt", "Ärztin", "Klinik", "Spital", "Gebühren", "Labor", "Medizinisch"]
                
                var medicalKeywordCount = 0
                for keyword in medicalKeywords {
                    if text.contains(keyword) {
                        medicalKeywordCount += 1
                    }
                }
                
                // Only proceed if it looks like a medical invoice
                if medicalKeywordCount >= 2 {
                    // Extract specific reference formats used in Swiss medical invoices
                    let referencePatterns = [
                        #"Referenz[:\s]*(\d[\s\d]+\d)"#,
                        #"Referenznummer[:\s]*(\d[\s\d]+\d)"#,
                        #"Reference[:\s]*(\d[\s\d]+\d)"#,
                        #"Ref\.[:\s]*(\d[\s\d]+\d)"#,
                        #"Ref[:\s]*(\d[\s\d]+\d)"#,
                        #"Zahlbar durch[:\s\S]*Referenz[:\s]*(\d[\s\d]+\d)"#
                    ]
                    
                    for pattern in referencePatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                            let nsText = text as NSString
                            let range = NSRange(location: 0, length: nsText.length)
                            
                            if let match = regex.firstMatch(in: text, options: [], range: range),
                               match.numberOfRanges >= 2,
                               let refRange = Range(match.range(at: 1), in: text) {
                                let reference = String(text[refRange])
                                    .replacingOccurrences(of: " ", with: "")
                                data.invoiceNumber = reference
                                break
                            }
                        }
                    }
                    
                    // Extract treatment date or service period
                    let treatmentPatterns = [
                        #"Behandlung[:\s]*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
                        #"Behandlungsdatum[:\s]*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
                        #"Leistungsperiode[:\s]*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})\s*-\s*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
                        #"Leistungsdatum[:\s]*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
                        #"Leistungserbringerin[:\s\S]*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#
                    ]
                    
                    for pattern in treatmentPatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                            let nsText = text as NSString
                            let range = NSRange(location: 0, length: nsText.length)
                            
                            if let match = regex.firstMatch(in: text, options: [], range: range),
                               match.numberOfRanges >= 2,
                               let dateRange = Range(match.range(at: 1), in: text) {
                                let dateString = String(text[dateRange])
                                
                                // If we haven't found a issue date yet, use this as issue date
                                if data.issueDate == nil, let date = extractDate(from: dateString) {
                                    data.issueDate = date
                                }
                            }
                        }
                    }
                    
                    // Look for patient information
                    let patientPatterns = [
                        #"Patient(in)?[:\s]*([^,\r\n]+)"#,
                        #"Patientin[:\s]*([^,\r\n]+)"#,
                        #"Patient Name[:\s]*([^,\r\n]+)"#,
                        #"Name[:\s]*([^,\r\n]+)"#
                    ]
                    
                    for pattern in patientPatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                            let nsText = text as NSString
                            let range = NSRange(location: 0, length: nsText.length)
                            
                            if let match = regex.firstMatch(in: text, options: [], range: range),
                               match.numberOfRanges >= 2,
                               let nameRange = Range(match.range(at: match.numberOfRanges - 1), in: text) {
                                let patientName = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // Add patient information to recipient if we haven't found one yet
                                if data.recipient == nil || data.recipient!.isEmpty {
                                    data.recipient = patientName
                                }
                            }
                        }
                    }
                    
                    // Extract invoice type (Honorar-Rechnung, etc.)
                    let invoiceTypePatterns = [
                        #"(Honorar-Rechnung)"#,
                        #"(Arztrechnung)"#,
                        #"(Laborrechnung)"#
                    ]
                    
                    for pattern in invoiceTypePatterns {
                        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                            let nsText = text as NSString
                            let range = NSRange(location: 0, length: nsText.length)
                            
                            if let match = regex.firstMatch(in: text, options: [], range: range),
                               match.numberOfRanges >= 1,
                               let typeRange = Range(match.range(at: 0), in: text) {
                                let invoiceType = String(text[typeRange])
                                
                                // Update the title if it's just a generic "Scanned Invoice"
                                if data.title == "Scanned Invoice" {
                                    data.title = invoiceType
                                }
                            }
                        }
                    }
                }
            }
        }
