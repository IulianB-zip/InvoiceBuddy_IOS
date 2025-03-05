//
//  DashboardViewModel.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/ViewModels/DashboardViewModel.swift
import Foundation
import Combine
import SwiftUI

class DashboardViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var cards: [Card] = []
    @Published var upcomingInvoices: [Invoice] = []
    @Published var overdueInvoices: [Invoice] = []
    @Published var monthlyTotals: [(month: Date, amount: Double)] = []
    @Published var totalDueAmount: Double = 0
    @Published var thisMonthStats: (total: Double, pending: Int, paid: Int, overdue: Int) = (0, 0, 0, 0)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()
    
    private let invoiceService: InvoiceService
    private let cardService: CardService
    private var cancellables = Set<AnyCancellable>()
    
    init(invoiceService: InvoiceService, cardService: CardService) {
        self.invoiceService = invoiceService
        self.cardService = cardService
        
        loadData()
        startDateChangeMonitoring()
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Publishers.Zip(
            invoiceService.fetchInvoices(),
            cardService.fetchCards()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] (invoices, cards) in
            self?.invoices = invoices
            self?.cards = cards
            self?.processData()
        }
        .store(in: &cancellables)
    }
    
    private func processData() {
        filterUpcomingInvoices()
        filterOverdueInvoices()
        calculateMonthlyTotals()
        calculateTotalDueAmount()
        calculateThisMonthStats()
    }
    
    private func filterUpcomingInvoices(limit: Int = 5) {
        upcomingInvoices = invoices
            .filter { $0.dueDate >= Date() && $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0 }
    }
    
    private func filterOverdueInvoices() {
        overdueInvoices = invoices
            .filter { $0.status == .overdue }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private func calculateMonthlyTotals() {
        let calendar = Calendar.current
        var monthlyData: [Date: Double] = [:]
        
        // Start with current month and go back 6 months
        var currentDate = Date()
        
        for monthOffset in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -monthOffset, to: currentDate) {
                let components = calendar.dateComponents([.year, .month], from: date)
                if let monthStartDate = calendar.date(from: components) {
                    monthlyData[monthStartDate] = 0
                }
            }
        }
        
        // Calculate total for each month
        for invoice in invoices {
            let invoiceComponents = calendar.dateComponents([.year, .month], from: invoice.dueDate)
            if let monthStartDate = calendar.date(from: invoiceComponents) {
                if monthlyData.keys.contains(monthStartDate) {
                    monthlyData[monthStartDate, default: 0] += invoice.amount
                }
            }
        }
        
        // Convert to array and sort by date
        monthlyTotals = monthlyData.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    private func calculateTotalDueAmount() {
        totalDueAmount = invoices
            .filter { $0.status != .paid }
            .reduce(0) { $0 + $1.amount }
    }
    
    private func calculateThisMonthStats() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedMonth)
        let month = calendar.component(.month, from: selectedMonth)
        
        let monthInvoices = invoices.filter { invoice in
            let invoiceYear = calendar.component(.year, from: invoice.dueDate)
            let invoiceMonth = calendar.component(.month, from: invoice.dueDate)
            return invoiceYear == year && invoiceMonth == month
        }
        
        let total = monthInvoices.reduce(0) { $0 + $1.amount }
        let pending = monthInvoices.filter { $0.status == .pending }.count
        let paid = monthInvoices.filter { $0.status == .paid }.count
        let overdue = monthInvoices.filter { $0.status == .overdue }.count
        
        thisMonthStats = (total: total, pending: pending, paid: paid, overdue: overdue)
    }
    
    private func startDateChangeMonitoring() {
        // Update calculations when selected month changes
        $selectedMonth
            .sink { [weak self] _ in
                self?.calculateThisMonthStats()
            }
            .store(in: &cancellables)
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
    
    func getTotalsByStatus() -> (pending: Double, paid: Double, overdue: Double) {
        let pendingTotal = invoices.filter { $0.status == .pending }.reduce(0) { $0 + $1.amount }
        let paidTotal = invoices.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount }
        let overdueTotal = invoices.filter { $0.status == .overdue }.reduce(0) { $0 + $1.amount }
        
        return (pending: pendingTotal, paid: paidTotal, overdue: overdueTotal)
    }
    
    func getMonthName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: selectedMonth)
    }
    
    func moveMonth(forward: Bool) {
        if let newDate = Calendar.current.date(byAdding: .month, value: forward ? 1 : -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}