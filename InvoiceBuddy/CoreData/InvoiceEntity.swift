//
//  InvoiceEntity.swift
//  InvoiceMate
//
//  Created by Iulian Bucatariu on 06.03.2025.
//

import Foundation
import CoreData

// Custom extensions for additional functionality
extension InvoiceEntity {
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "No Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }
}

extension CardEntity {
    var maskedCardNumber: String {
        guard let lastFourDigits = lastFourDigits else { return "" }
        return "**** **** **** \(lastFourDigits)"
    }
}

extension MonthSettingEntity {
    // Additional computed properties or methods for MonthSetting
    var totalExpenses: Double {
        guard let expenses = annualExpenses as? Set<AnnualExpenseEntity> else { return 0 }
        return expenses.reduce(0) { $0 + $1.amount }
    }
}

extension AnnualExpenseEntity {
    var formattedExpenseAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

extension PaydayEntity {
    var formattedPaydayDate: String {
        guard let date = date else { return "No Date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
