//
//  PaymentPrioritizer.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// PaymentPrioritizer.swift
import Foundation

class PaymentPrioritizer {
    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // Main function to prioritize and schedule payments
    func prioritizePayments() -> [PaymentSchedule] {
        let invoices = dataManager.invoices.filter { $0.status == .pending }
        let paydays = dataManager.loadPaydays().sorted()
        let monthSettings = dataManager.monthSettings
        
        if invoices.isEmpty || paydays.isEmpty {
            return []
        }
        
        // Sort invoices by due date
        let sortedInvoices = invoices.sorted { $0.dueDate < $1.dueDate }
        
        // Create payment schedules
        var paymentSchedules: [PaymentSchedule] = []
        
        // Assign invoices to paydays
        for invoice in sortedInvoices {
            // Find the best payday for this invoice
            if let bestPayday = findBestPayday(for: invoice, paydays: paydays, existingSchedules: paymentSchedules) {
                // Check if this month is critical or low income
                let isInCriticalMonth = isInCriticalOrLowIncomeMonth(date: invoice.dueDate, monthSettings: monthSettings)
                
                // Add to schedule
                let schedule = PaymentSchedule(
                    invoice: invoice,
                    paymentDate: bestPayday,
                    priority: calculatePriority(invoice: invoice, isInCriticalMonth: isInCriticalMonth)
                )
                
                paymentSchedules.append(schedule)
            }
        }
        
        // Sort schedules by payday, then by priority
        return sortSchedulesByPriorityAndDate(paymentSchedules)
    }
    
    // Find the best payday for an invoice
    private func findBestPayday(for invoice: Invoice, paydays: [Date], existingSchedules: [PaymentSchedule]) -> Date? {
        let calendar = Calendar.current
        
        // Find paydays that are before the due date but not in the past
        let now = Date()
        let eligiblePaydays = paydays.filter { payday in
            payday <= invoice.dueDate && payday >= now
        }
        
        if eligiblePaydays.isEmpty {
            // No eligible paydays before due date, find the closest payday in the past
            let pastPaydays = paydays.filter { $0 < invoice.dueDate }
            return pastPaydays.last
        }
        
        // Find the payday that is closest to the due date but still before it
        var bestPayday = eligiblePaydays.last!
        
        // Consider the load on each payday (how many invoices are already assigned)
        let paydayLoads = calculatePaydayLoads(existingSchedules)
        
        // If the best payday by date has too many invoices, try to find an earlier payday
        if let load = paydayLoads[bestPayday], load > 5 {
            // Look for earlier paydays with lighter loads
            for payday in eligiblePaydays.reversed().dropFirst() {
                if let currentLoad = paydayLoads[payday], currentLoad < load - 1 {
                    bestPayday = payday
                    break
                }
            }
        }
        
        return bestPayday
    }
    
    // Calculate how many invoices are already assigned to each payday
    private func calculatePaydayLoads(_ schedules: [PaymentSchedule]) -> [Date: Int] {
        var loads: [Date: Int] = [:]
        
        for schedule in schedules {
            loads[schedule.paymentDate, default: 0] += 1
        }
        
        return loads
    }
    
    // Calculate priority for an invoice
    private func calculatePriority(invoice: Invoice, isInCriticalMonth: Bool) -> Int {
        var priority = invoice.priority
        
        // Increase priority for invoices that are due soon
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: invoice.dueDate).day ?? 0
        if daysUntilDue <= 3 {
            priority += 3
        } else if daysUntilDue <= 7 {
            priority += 2
        } else if daysUntilDue <= 14 {
            priority += 1
        }
        
        // Increase priority for larger amounts
        if invoice.amount > 1000 {
            priority += 3
        } else if invoice.amount > 500 {
            priority += 2
        } else if invoice.amount > 100 {
            priority += 1
        }
        
        // Increase priority for critical months
        if isInCriticalMonth {
            priority += 2
        }
        
        return priority
    }
    
    // Check if a date falls in a critical or low income month
    private func isInCriticalOrLowIncomeMonth(date: Date, monthSettings: [MonthSetting]) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        return monthSettings.contains { setting in
            setting.year == year && setting.month == month && (setting.isCritical || setting.isLowIncome)
        }
    }
    
    // Sort payment schedules by payday and priority
    private func sortSchedulesByPriorityAndDate(_ schedules: [PaymentSchedule]) -> [PaymentSchedule] {
        return schedules.sorted { first, second in
            if first.paymentDate == second.paymentDate {
                return first.priority > second.priority // Higher priority first
            }
            return first.paymentDate < second.paymentDate // Earlier date first
        }
    }
}

// Payment Schedule struct
struct PaymentSchedule {
    let invoice: Invoice
    let paymentDate: Date
    let priority: Int
    
    var isWeekendPayment: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: paymentDate)
        return weekday == 1 || weekday == 7 // 1 = Sunday, 7 = Saturday
    }
    
    var adjustedPaymentDate: Date {
        if isWeekendPayment {
            // If it's a weekend, move to Friday before
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: paymentDate)
            
            if weekday == 1 { // Sunday
                return calendar.date(byAdding: .day, value: -2, to: paymentDate)!
            } else if weekday == 7 { // Saturday
                return calendar.date(byAdding: .day, value: -1, to: paymentDate)!
            }
        }
        
        return paymentDate
    }
}

// Extension to DataManager for payment prioritization
extension DataManager {
    func generatePaymentSchedule() -> [PaymentSchedule] {
        let prioritizer = PaymentPrioritizer(dataManager: self)
        return prioritizer.prioritizePayments()
    }
    
    // Update invoice priorities based on various factors
    func updateInvoicePriorities() {
        for i in 0..<invoices.count {
            // Base priority adjustments
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: invoices[i].dueDate).day ?? 0
            
            if daysUntilDue <= 3 {
                invoices[i].priority = max(invoices[i].priority, 5)
            } else if daysUntilDue <= 7 {
                invoices[i].priority = max(invoices[i].priority, 4)
            }
            
            // Check if in critical month
            let calendar = Calendar.current
            let year = calendar.component(.year, from: invoices[i].dueDate)
            let month = calendar.component(.month, from: invoices[i].dueDate)
            
            let isCriticalMonth = monthSettings.contains { setting in
                setting.year == year && setting.month == month && setting.isCritical
            }
            
            if isCriticalMonth {
                invoices[i].priority += 1
            }
        }
        
        // Save updated priorities
        for invoice in invoices {
            CoreDataManager.shared.updateInvoice(invoice)
        }
    }
}