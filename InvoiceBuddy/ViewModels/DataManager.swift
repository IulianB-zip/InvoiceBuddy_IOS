//
//  DataManager.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// DataManager.swift
import Foundation
import Combine
import SwiftUI

class DataManager: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var userCards: [Card] = []
    @Published var monthSettings: [MonthSetting] = []
    @Published var paymentMethods: [PaymentMethod] = PaymentMethod.allCases
    
    private let persistenceService: PersistenceService
    private let notificationService: NotificationService
    
    init(persistenceService: PersistenceService = CoreDataManager.shared,
         notificationService: NotificationService = UNNotificationService()) {
        self.persistenceService = persistenceService
        self.notificationService = notificationService
        
        loadInitialData()
    }
    
    private func loadInitialData() {
        loadInvoices()
        loadCards() 
        loadMonthSettings()
    }
    
    func loadInvoices() {
        invoices = persistenceService.fetchInvoices()
    }
    
    func saveInvoice(_ invoice: Invoice) {
        persistenceService.saveInvoice(invoice)
        loadInvoices()
        
        if let reminderDate = invoice.reminderDate {
            notificationService.scheduleReminderForInvoice(invoice)
        }
    }
    
    // Additional methods...
}