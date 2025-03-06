// InvoiceModel.swift
import Foundation

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case paid = "Paid"
    case overdue = "Overdue"
    
    var color: String {
        switch self {
        case .pending: return "yellow"
        case .paid: return "green"
        case .overdue: return "red"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case bankTransfer = "Bank Transfer"
    case cash = "Cash"
    case other = "Other"
}

struct Invoice: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var amount: Double
    var dueDate: Date
    var status: PaymentStatus = .pending
    var paymentMethod: PaymentMethod?
    var reminderDate: Date?
    var barcode: String?
    var qrData: String?
    var notes: String?
    var priority: Int = 0 // Higher number means higher priority
    var isPaid: Bool = false
    var paymentDate: Date?
    var associatedCardId: String?
    
    var isOverdue: Bool {
        if status == .paid {
            return false
        }
        return Date() > dueDate
    }
    
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
    
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: dueDate)
        return components.day ?? 0
    }
}
