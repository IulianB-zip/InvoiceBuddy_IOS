//
//  MonthSetting.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
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
}

struct AnnualExpense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var dueDate: Date
}