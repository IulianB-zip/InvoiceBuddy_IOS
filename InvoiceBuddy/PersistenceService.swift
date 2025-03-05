//
//  PersistenceService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// PersistenceService.swift
import Foundation

protocol PersistenceService {
    // Invoice methods
    func fetchInvoices() -> [Invoice]
    func saveInvoice(_ invoice: Invoice)
    func updateInvoice(_ invoice: Invoice)
    func deleteInvoice(id: UUID)
    
    // Card methods
    func fetchCards() -> [Card]
    func saveCard(_ card: Card)
    func deleteCard(id: UUID)
    
    // Month settings methods
    func fetchMonthSettings() -> [MonthSetting]
    func fetchMonthSetting(year: Int, month: Int) -> [MonthSetting]
    func saveMonthSetting(_ setting: MonthSetting)
    
    // Payday methods
    func fetchPaydays() -> [Date]
    func savePayday(_ date: Date)
    func deletePayday(date: Date)
}