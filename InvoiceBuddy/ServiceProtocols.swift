// Service Protocols for InvoiceBuddy

// InvoiceService.swift
import Foundation
import Combine

protocol InvoiceService {
    func fetchInvoices() -> AnyPublisher<[Invoice], Error>
    func saveInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error>
    func updateInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error>
    func deleteInvoice(id: UUID) -> AnyPublisher<Void, Error>
    func getInvoicesByMonth(year: Int, month: Int) -> AnyPublisher<[Invoice], Error>
    func getUpcomingInvoices(limit: Int) -> AnyPublisher<[Invoice], Error>
}

// CardService.swift
import Foundation
import Combine

protocol CardService {
    func fetchCards() -> AnyPublisher<[Card], Error>
    func saveCard(_ card: Card) -> AnyPublisher<Void, Error>
    func updateCard(_ card: Card) -> AnyPublisher<Void, Error>
    func deleteCard(id: UUID) -> AnyPublisher<Void, Error>
    func getDefaultCard() -> AnyPublisher<Card?, Error>
}

// MonthSettingService.swift
import Foundation
import Combine

protocol MonthSettingService {
    func fetchMonthSettings() -> AnyPublisher<[MonthSetting], Error>
    func fetchMonthSetting(year: Int, month: Int) -> AnyPublisher<MonthSetting?, Error>
    func saveMonthSetting(_ setting: MonthSetting) -> AnyPublisher<Void, Error>
    func deleteMonthSetting(id: UUID) -> AnyPublisher<Void, Error>
}

// PaydayService.swift
import Foundation
import Combine

protocol PaydayService {
    func fetchPaydays() -> AnyPublisher<[Date], Error>
    func savePayday(_ date: Date) -> AnyPublisher<Void, Error>
    func deletePayday(date: Date) -> AnyPublisher<Void, Error>
    func getNextPayday(after date: Date) -> AnyPublisher<Date?, Error>
}

// PrioritizationService.swift
import Foundation
import Combine

protocol PrioritizationService {
    func prioritizeInvoices() -> AnyPublisher<[PrioritizedInvoice], Error>
    func distributeInvoicesAcrossPaydays() -> AnyPublisher<[PaymentSchedule], Error>
    func updateInvoicePriorities() -> AnyPublisher<Void, Error>
}

// Models for prioritization
struct PrioritizedInvoice {
    let invoice: Invoice
    let priority: Int
    let paymentDate: Date?
    let notes: String?
}

struct PaymentSchedule {
    let payday: Date
    let invoices: [PrioritizedInvoice]
    let totalAmount: Double
}

// Implementation of PrioritizationService
class PrioritizationServiceImpl: PrioritizationService {
    private let invoiceService: InvoiceService
    private let paydayService: PaydayService
    private let monthSettingService: MonthSettingService
    
    init(invoiceService: InvoiceService, paydayService: PaydayService, monthSettingService: MonthSettingService) {
        self.invoiceService = invoiceService
        self.paydayService = paydayService
        self.monthSettingService = monthSettingService
    }
    
    func prioritizeInvoices() -> AnyPublisher<[PrioritizedInvoice], Error> {
        return invoiceService.fetchInvoices()
            .flatMap { [weak self] invoices -> AnyPublisher<[PrioritizedInvoice], Error> in
                guard let self = self else {
                    return Fail(error: AppError.databaseError("Self reference lost")).eraseToAnyPublisher()
                }
                
                let pendingInvoices = invoices.filter { $0.status == .pending }
                
                if pendingInvoices.isEmpty {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                return self.calculatePriorities(for: pendingInvoices)
            }
            .eraseToAnyPublisher()
    }
    
    func distributeInvoicesAcrossPaydays() -> AnyPublisher<[PaymentSchedule], Error> {
        return Publishers.Zip(
            prioritizeInvoices(),
            paydayService.fetchPaydays()
        )
        .flatMap { [weak self] (prioritizedInvoices, paydays) -> AnyPublisher<[PaymentSchedule], Error> in
            guard let self = self else {
                return Fail(error: AppError.databaseError("Self reference lost")).eraseToAnyPublisher()
            }
            
            // Filter future paydays
            let futurePaydays = paydays.filter { $0 > Date() }.sorted()
            
            if futurePaydays.isEmpty || prioritizedInvoices.isEmpty {
                return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            
            return self.assignInvoicesToPaydays(prioritizedInvoices, futurePaydays)
        }
        .eraseToAnyPublisher()
    }
    
    func updateInvoicePriorities() -> AnyPublisher<Void, Error> {
        return prioritizeInvoices()
            .flatMap { [weak self] prioritizedInvoices -> AnyPublisher<Void, Error> in
                guard let self = self else {
                    return Fail(error: AppError.databaseError("Self reference lost")).eraseToAnyPublisher()
                }
                
                let publishers = prioritizedInvoices.map { prioritizedInvoice -> AnyPublisher<Void, Error> in
                    var updatedInvoice = prioritizedInvoice.invoice
                    updatedInvoice.priority = prioritizedInvoice.priority
                    
                    return self.invoiceService.updateInvoice(updatedInvoice)
                }
                
                return Publishers.MergeMany(publishers)
                    .collect()
                    .map { _ in () }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // Helper methods
    
    private func calculatePriorities(for invoices: [Invoice]) -> AnyPublisher<[PrioritizedInvoice], Error> {
        return monthSettingService.fetchMonthSettings()
            .map { [weak self] monthSettings -> [PrioritizedInvoice] in
                guard let self = self else { return [] }
                
                return invoices.map { invoice in
                    let priority = self.calculatePriority(for: invoice, withMonthSettings: monthSettings)
                    return PrioritizedInvoice(
                        invoice: invoice,
                        priority: priority,
                        paymentDate: nil, // Will be assigned in distributeInvoicesAcrossPaydays
                        notes: nil
                    )
                }.sorted { $0.priority > $1.priority } // Higher priority first
            }
            .eraseToAnyPublisher()
    }
    
    private func calculatePriority(for invoice: Invoice, withMonthSettings monthSettings: [MonthSetting]) -> Int {
        var priority = invoice.priority
        
        // Factor 1: Days until due
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: invoice.dueDate).day ?? 0
        if daysUntilDue <= 2 {
            priority += 5
        } else if daysUntilDue <= 5 {
            priority += 3
        } else if daysUntilDue <= 10 {
            priority += 1
        }
        
        // Factor 2: Amount
        if invoice.amount > 1000 {
            priority += 3
        } else if invoice.amount > 500 {
            priority += 2
        } else if invoice.amount > 100 {
            priority += 1
        }
        
        // Factor 3: Month criticality
        let calendar = Calendar.current
        let year = calendar.component(.year, from: invoice.dueDate)
        let month = calendar.component(.month, from: invoice.dueDate)
        
        let isCriticalMonth = monthSettings.contains { setting in
            setting.year == year && setting.month == month && setting.isCritical
        }
        
        let isLowIncomeMonth = monthSettings.contains { setting in
            setting.year == year && setting.month == month && setting.isLowIncome
        }
        
        if isCriticalMonth {
            priority += 3
        }
        
        if isLowIncomeMonth {
            priority += 2
        }
        
        return priority
    }
    
    private func assignInvoicesToPaydays(_ prioritizedInvoices: [PrioritizedInvoice], _ paydays: [Date]) -> AnyPublisher<[PaymentSchedule], Error> {
        return Just(prioritizedInvoices)
            .setFailureType(to: Error.self)
            .map { invoices -> [PaymentSchedule] in
                var result: [PaymentSchedule] = []
                var remainingInvoices = invoices
                
                // Initialize payment schedules for each payday
                for payday in paydays {
                    result.append(PaymentSchedule(payday: payday, invoices: [], totalAmount: 0))
                }
                
                // First pass: assign invoices with due dates closest to each payday
                for (index, payday) in paydays.enumerated() {
                    let nextPayday = index < paydays.count - 1 ? paydays[index + 1] : Date.distantFuture
                    
                    // Find invoices due after this payday but before the next one
                    let invoicesDueInThisPeriod = remainingInvoices.filter { prioritizedInvoice in
                        let dueDate = prioritizedInvoice.invoice.dueDate
                        return dueDate >= payday && dueDate < nextPayday
                    }
                    
                    if !invoicesDueInThisPeriod.isEmpty {
                        // Add these invoices to this payday's schedule
                        var schedule = result[index]
                        schedule.invoices.append(contentsOf: invoicesDueInThisPeriod)
                        schedule.totalAmount = invoicesDueInThisPeriod.reduce(0) { $0 + $1.invoice.amount }
                        result[index] = schedule
                        
                        // Remove these invoices from the remaining set
                        remainingInvoices.removeAll { invoicesDueInThisPeriod.contains { $0.invoice.id == $1.invoice.id } }
                    }
                }
                
                // Second pass: assign remaining invoices to the closest payday before due date
                for prioritizedInvoice in remainingInvoices {
                    let dueDate = prioritizedInvoice.invoice.dueDate
                    
                    // Find the closest payday before the due date
                    let eligiblePaydays = paydays.filter { $0 <= dueDate }
                    if let closestPayday = eligiblePaydays.last {
                        let paydayIndex = paydays.firstIndex(of: closestPayday) ?? 0
                        
                        // Add to this payday's schedule
                        var schedule = result[paydayIndex]
                        schedule.invoices.append(prioritizedInvoice)
                        schedule.totalAmount += prioritizedInvoice.invoice.amount
                        result[paydayIndex] = schedule
                    } else {
                        // If no eligible payday, assign to the first future payday
                        if let firstPayday = paydays.first {
                            let paydayIndex = 0
                            var schedule = result[paydayIndex]
                            schedule.invoices.append(prioritizedInvoice)
                            schedule.totalAmount += prioritizedInvoice.invoice.amount
                            result[paydayIndex] = schedule
                        }
                    }
                }
                
                // Sort invoices within each schedule by priority
                return result.map { schedule in
                    var updatedSchedule = schedule
                    updatedSchedule.invoices.sort { $0.priority > $1.priority }
                    return updatedSchedule
                }
            }
            .eraseToAnyPublisher()
    }
}

// ScanningServiceProtocol.swift
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

// ScannedInvoiceData.swift
import Foundation

struct ScannedInvoiceData {
    var rawData: String
    var title: String?
    var description: String?
    var amount: Double?
    var dueDate: Date?
    var barcode: String?
    var qrData: String?
    
    init(rawData: String) {
        self.rawData = rawData
        self.barcode = rawData
        self.qrData = rawData
        parseData()
    }
    
    mutating func parseData() {
        // Try to parse as JSON first
        if let jsonData = rawData.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    self.title = json["title"] as? String
                    self.description = json["description"] as? String
                    
                    if let amountString = json["amount"] as? String {
                        self.amount = Double(amountString)
                    } else {
                        self.amount = json["amount"] as? Double
                    }
                    
                    if let dueDateString = json["dueDate"] as? String {
                        let dateFormatter = DateFormatter()
                        // Try multiple date formats
                        let dateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd"]
                        
                        for format in dateFormats {
                            dateFormatter.dateFormat = format
                            if let date = dateFormatter.date(from: dueDateString) {
                                self.dueDate = date
                                break
                            }
                        }
                    }
                    return
                }
            } catch {
                // Not valid JSON, continue with other parsing methods
            }
        }
        
        // Try to parse as key-value pairs (e.g., "title=Electric Bill&amount=75.50&due=2023-04-15")
        let components = rawData.components(separatedBy: "&")
        
        for component in components {
            let keyValue = component.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0].lowercased()
                let value = keyValue[1]
                
                switch key {
                case "title":
                    self.title = value
                case "description", "desc":
                    self.description = value
                case "amount", "amt":
                    self.amount = Double(value)
                case "due", "duedate":
                    let dateFormatter = DateFormatter()
                    // Try multiple date formats
                    let dateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd"]
                    
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: value) {
                            self.dueDate = date
                            break
                        }
                    }
                default:
                    break
                }
            }
        }
        
        // If still no structured data found, try to extract information from text
        if title == nil && description == nil && amount == nil && dueDate == nil {
            extractInformationFromText()
        }
    }
    
    mutating func extractInformationFromText() {
        // Look for amount patterns (e.g., $123.45, 123.45 USD)
        let amountPattern = #"\$?(\d+(\.\d{1,2})?)\s*(USD|EUR|GBP)?"#
        if let amountMatch = rawData.range(of: amountPattern, options: .regularExpression) {
            let amountString = rawData[amountMatch].replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "USD", with: "")
                .replacingOccurrences(of: "EUR", with: "")
                .replacingOccurrences(of: "GBP", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.amount = Double(amountString)
        }
        
        // Look for date patterns
        let datePatterns = [
            #"\d{2}/\d{2}/\d{4}"#, // MM/DD/YYYY or DD/MM/YYYY
            #"\d{4}-\d{2}-\d{2}"#, // YYYY-MM-DD
            #"\d{2}-\d{2}-\d{4}"#  // MM-DD-YYYY or DD-MM-YYYY
        ]
        
        for pattern in datePatterns {
            if let dateMatch = rawData.range(of: pattern, options: .regularExpression) {
                let dateString = String(rawData[dateMatch])
                let dateFormatter = DateFormatter()
                
                if pattern == #"\d{2}/\d{2}/\d{4}"# {
                    dateFormatter.dateFormat = "MM/dd/yyyy" // Assuming MM/DD/YYYY format
                } else if pattern == #"\d{4}-\d{2}-\d{2}"# {
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                } else {
                    dateFormatter.dateFormat = "MM-dd-yyyy" // Assuming MM-DD-YYYY format
                }
                
                if let date = dateFormatter.date(from: dateString) {
                    self.dueDate = date
                    break
                }
            }
        }
        
        // Set a generic title if none was found
        if self.title == nil {
            if rawData.count > 30 {
                self.title = "Scanned Invoice"
                self.description = String(rawData.prefix(100))
            } else {
                self.title = rawData
            }
        }
    }
}
