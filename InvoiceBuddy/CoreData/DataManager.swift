//
//  DataManager.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//

import Foundation
import SwiftUI
import Combine

class DataManager: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var userCards: [Card] = []
    @Published var monthSettings: [MonthSetting] = []
    @Published var paydays: [Payday] = []
    @Published var isLoading = false
    
    // Add app settings and default currency
    @AppStorage("defaultCurrency") private var defaultCurrencyString = Currency.default.rawValue
    @Published var defaultCurrency = Currency.default
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set default currency from saved setting
        defaultCurrency = Currency(rawValue: defaultCurrencyString) ?? .default
        loadAll()
    }
    
    func loadAll() {
        isLoading = true
        
        loadInvoices()
        loadCards()
        loadMonthSettings()
        loadPaydays()
        
        isLoading = false
    }
    
    // MARK: - Invoice Methods
    
    func loadInvoices() {
        invoices = CoreDataManager.shared.fetchInvoices()
        updateInvoiceStatuses()
    }
    
    func saveInvoice(_ invoice: Invoice) {
        CoreDataManager.shared.saveInvoice(invoice)
        loadInvoices()
        
        // Schedule notification
        scheduleReminderForInvoice(invoice)
    }
    
    func deleteInvoice(at offsets: IndexSet) {
        for index in offsets {
            let invoice = invoices[index]
            CoreDataManager.shared.deleteInvoice(id: invoice.id)
            
            // Cancel any scheduled notifications
            cancelNotificationForInvoice(invoice)
        }
        loadInvoices()
    }
    
    func updateInvoiceStatuses() {
        let today = Date()
        var updated = false
        
        for i in 0..<invoices.count {
            if invoices[i].dueDate < today && invoices[i].status == .pending {
                invoices[i].status = .overdue
                CoreDataManager.shared.updateInvoice(invoices[i])
                updated = true
            }
        }
        
        if updated {
            loadInvoices()
        }
    }
    
    // MARK: - Card Methods
    
    func loadCards() {
        userCards = CoreDataManager.shared.fetchCards()
    }
    
    func saveCard(_ card: Card) {
        CoreDataManager.shared.saveCard(card)
        loadCards()
    }
    
    func deleteCard(at offsets: IndexSet) {
        for index in offsets {
            let card = userCards[index]
            CoreDataManager.shared.deleteCard(id: card.id)
        }
        loadCards()
    }
    
    // MARK: - Month Settings Methods
    
    func loadMonthSettings() {
        monthSettings = CoreDataManager.shared.fetchMonthSettings()
    }
    
    func saveMonthSetting(_ setting: MonthSetting) {
        CoreDataManager.shared.saveMonthSetting(setting)
        loadMonthSettings()
    }
    
    // MARK: - Payday Methods
    
    func loadPaydays() {
        paydays = CoreDataManager.shared.fetchPaydays()
    }
    
    func savePayday(_ payday: Payday) {
        CoreDataManager.shared.savePayday(payday)
        loadPaydays()
    }
    
    func deletePayday(_ id: UUID) {
        CoreDataManager.shared.deletePayday(id: id)
        loadPaydays()
    }
    
    // MARK: - Notification Methods
    
    func scheduleReminderForInvoice(_ invoice: Invoice) {
        guard let reminderDate = invoice.reminderDate else { return }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        // Request authorization if not already granted
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if !granted || error != nil {
                print("Notification permission not granted or error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Invoice Payment Reminder"
            content.body = "\(invoice.title) is due soon. Amount: \(self.formatAmount(invoice.amount))"
            content.sound = .default
            
            // Create trigger based on reminder date
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "invoice-\(invoice.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            // Add request to notification center
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelNotificationForInvoice(_ invoice: Invoice) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["invoice-\(invoice.id.uuidString)"])
    }
    
    // MARK: - Payment Prioritization
    
    func getPrioritizedInvoices() -> [Invoice] {
        // Sort pending invoices by due date, then by priority
        return invoices
            .filter { $0.status == .pending }
            .sorted { first, second in
                if first.dueDate == second.dueDate {
                    return first.priority > second.priority
                }
                return first.dueDate < second.dueDate
            }
    }
    
    func getOverdueInvoices() -> [Invoice] {
        return invoices.filter { $0.status == .overdue }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    func getPaidInvoices() -> [Invoice] {
        return invoices.filter { $0.status == .paid }
            .sorted { $0.paymentDate ?? Date() > $1.paymentDate ?? Date() }
    }
    
    func getUpcomingInvoices(limit: Int = 10) -> [Invoice] {
        return invoices
            .filter { $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0 }
    }
    
    func getTotalDueThisMonth() -> Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return invoices
            .filter { invoice in
                let month = calendar.component(.month, from: invoice.dueDate)
                let year = calendar.component(.year, from: invoice.dueDate)
                return month == currentMonth && year == currentYear && invoice.status != .paid
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getInvoicesForMonth(month: Int, year: Int) -> [Invoice] {
        let calendar = Calendar.current
        
        return invoices.filter { invoice in
            let invoiceMonth = calendar.component(.month, from: invoice.dueDate)
            let invoiceYear = calendar.component(.year, from: invoice.dueDate)
            return invoiceMonth == month && invoiceYear == year
        }
    }
    
    func isMonthCritical(month: Int, year: Int) -> Bool {
        return monthSettings.contains { setting in
            setting.month == month && setting.year == year && setting.isCritical
        }
    }
    
    func isMonthLowIncome(month: Int, year: Int) -> Bool {
        return monthSettings.contains { setting in
            setting.month == month && setting.year == year && setting.isLowIncome
        }
    }
    
    func markInvoiceAsPaid(_ invoice: Invoice) {
        var updatedInvoice = invoice
        updatedInvoice.status = .paid
        updatedInvoice.isPaid = true
        updatedInvoice.paymentDate = Date()
        
        CoreDataManager.shared.updateInvoice(updatedInvoice)
        loadInvoices()
    }
    
    // MARK: - Currency Methods
    
    // Update default currency
    func updateDefaultCurrency(_ currency: Currency) {
        defaultCurrency = currency
        defaultCurrencyString = currency.rawValue
    }
    
    // Format amount using default currency
    func formatAmount(_ amount: Double) -> String {
        return defaultCurrency.formatAmount(amount)
    }
    
    // Create a new invoice with default values including currency
    func createNewInvoice() -> Invoice {
        return Invoice(
            id: UUID(),
            title: "",
            description: "",
            amount: 0.0,
            dueDate: Date(),
            status: .pending,
            paymentMethod: nil,
            reminderDate: nil,
            barcode: nil,
            qrData: nil,
            notes: nil,
            priority: 0,
            isPaid: false,
            paymentDate: nil,
            associatedCardId: nil
        )
    }
}
