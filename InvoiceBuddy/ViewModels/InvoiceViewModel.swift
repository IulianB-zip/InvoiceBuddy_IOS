//
//  InvoiceViewModel.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// InvoiceViewModel.swift
import Foundation
import Combine
import SwiftUI

class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var upcomingInvoices: [Invoice] = []
    @Published var overdueInvoices: [Invoice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var monthlyTotal: Double = 0
    @Published var selectedMonth: Date = Date()
    
    private let invoiceService: InvoiceService
    private let notificationService: NotificationService
    private var cancellables = Set<AnyCancellable>()
    
    init(invoiceService: InvoiceService, notificationService: NotificationService) {
        self.invoiceService = invoiceService
        self.notificationService = notificationService
        
        loadInvoices()
        startDateChangeMonitoring()
    }
    
    func loadInvoices() {
        isLoading = true
        errorMessage = nil
        
        invoiceService.fetchInvoices()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] invoices in
                self?.invoices = invoices
                self?.processInvoices()
                self?.calculateMonthlyTotal()
            }
            .store(in: &cancellables)
    }
    
    func saveInvoice(_ invoice: Invoice) {
        isLoading = true
        errorMessage = nil
        
        invoiceService.saveInvoice(invoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadInvoices()
                }
            } receiveValue: { [weak self] _ in
                // Schedule notification if there's a reminder date
                if let reminderDate = invoice.reminderDate {
                    self?.notificationService.scheduleReminderForInvoice(invoice)
                }
            }
            .store(in: &cancellables)
    }
    
    func updateInvoice(_ invoice: Invoice) {
        isLoading = true
        errorMessage = nil
        
        invoiceService.updateInvoice(invoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadInvoices()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func deleteInvoice(at indexSet: IndexSet) {
        for index in indexSet {
            let invoice = invoices[index]
            
            isLoading = true
            errorMessage = nil
            
            invoiceService.deleteInvoice(id: invoice.id)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.loadInvoices()
                    }
                } receiveValue: { [weak self] _ in
                    // Cancel any scheduled notifications
                    self?.notificationService.cancelReminderForInvoice(id: invoice.id)
                }
                .store(in: &cancellables)
        }
    }
    
    func markAsPaid(_ invoice: Invoice) {
        var updatedInvoice = invoice
        updatedInvoice.status = .paid
        updatedInvoice.isPaid = true
        updatedInvoice.paymentDate = Date()
        
        updateInvoice(updatedInvoice)
    }
    
    func getInvoicesByStatus(_ status: PaymentStatus) -> [Invoice] {
        return invoices.filter { $0.status == status }
    }
    
    func getInvoicesForCurrentMonth() -> [Invoice] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedMonth)
        let month = calendar.component(.month, from: selectedMonth)
        
        return invoices.filter { invoice in
            let invoiceYear = calendar.component(.year, from: invoice.dueDate)
            let invoiceMonth = calendar.component(.month, from: invoice.dueDate)
            return invoiceYear == year && invoiceMonth == month
        }
    }
    
    // MARK: - Private Methods
    
    private func processInvoices() {
        updateOverdueInvoices()
        filterUpcomingInvoices()
    }
    
    private func updateOverdueInvoices() {
        let today = Date()
        var updatedAny = false
        
        for (index, invoice) in invoices.enumerated() {
            if invoice.dueDate < today && invoice.status == .pending {
                var updatedInvoice = invoice
                updatedInvoice.status = .overdue
                
                invoiceService.updateInvoice(updatedInvoice)
                    .sink { _ in } receiveValue: { _ in }
                    .store(in: &cancellables)
                
                // Update local array without reloading
                invoices[index].status = .overdue
                updatedAny = true
            }
        }
        
        if updatedAny {
            self.overdueInvoices = invoices.filter { $0.status == .overdue }
        }
    }
    
    private func filterUpcomingInvoices(limit: Int = 5) {
        upcomingInvoices = invoices
            .filter { $0.dueDate >= Date() && $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0 }
    }
    
    private func calculateMonthlyTotal() {
        monthlyTotal = getInvoicesForCurrentMonth()
            .filter { $0.status != .paid }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func startDateChangeMonitoring() {
        // Update calculations when selected month changes
        $selectedMonth
            .sink { [weak self] _ in
                self?.calculateMonthlyTotal()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Analytics Methods
    
    func getMonthlyTotals(for months: Int = 6) -> [(month: Date, amount: Double)] {
        let calendar = Calendar.current
        var result: [(month: Date, amount: Double)] = []
        
        // Start with current month and go back
        var currentDate = Date()
        
        for _ in 0..<months {
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            
            // Create a date representing this month
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            
            if let monthDate = calendar.date(from: components) {
                let monthlyTotal = invoices
                    .filter { invoice in
                        let invoiceYear = calendar.component(.year, from: invoice.dueDate)
                        let invoiceMonth = calendar.component(.month, from: invoice.dueDate)
                        return invoiceYear == year && invoiceMonth == month
                    }
                    .reduce(0) { $0 + $1.amount }
                
                result.append((month: monthDate, amount: monthlyTotal))
            }
            
            // Go back one month
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        }
        
        return result.reversed() // Return in chronological order
    }
    
    func getPaymentMethodDistribution() -> [PaymentMethod: Double] {
        let totalInvoices = Double(invoices.count)
        guard totalInvoices > 0 else { return [:] }
        
        var methodCounts: [PaymentMethod: Int] = [:]
        
        for invoice in invoices {
            if let method = invoice.paymentMethod {
                methodCounts[method, default: 0] += 1
            }
        }
        
        var percentages: [PaymentMethod: Double] = [:]
        for (method, count) in methodCounts {
            percentages[method] = Double(count) / totalInvoices * 100
        }
        
        return percentages
    }
    
    func getMonthStats(for date: Date) -> (total: Double, pending: Int, paid: Int, overdue: Int) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        let monthInvoices = invoices.filter { invoice in
            let invoiceYear = calendar.component(.year, from: invoice.dueDate)
            let invoiceMonth = calendar.component(.month, from: invoice.dueDate)
            return invoiceYear == year && invoiceMonth == month
        }
        
        let total = monthInvoices.reduce(0) { $0 + $1.amount }
        let pending = monthInvoices.filter { $0.status == .pending }.count
        let paid = monthInvoices.filter { $0.status == .paid }.count
        let overdue = monthInvoices.filter { $0.status == .overdue }.count
        
        return (total: total, pending: pending, paid: paid, overdue: overdue)
    }
}