//
//  MonthSetting.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// MonthSetting.swift
import Foundation

struct MonthSetting: Identifiable, Codable {
    var id = UUID()
    var year: Int
    var month: Int
    var isCritical: Bool = false
    var isLowIncome: Bool = false
    var note: String?
    var annualExpenses: [AnnualExpense] = []
    
    var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        
        var components = DateComponents()
        components.year = year
        components.month = month
        
        if let date = Calendar.current.date(from: components) {
            return dateFormatter.string(from: date)
        }
        return ""
    }
    
    var displayName: String {
        return "\(monthName) \(year)"
    }
    
    var totalAnnualExpenses: Double {
        return annualExpenses.reduce(0) { $0 + $1.amount }
    }
}

struct AnnualExpense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var dueDate: Date
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }
}