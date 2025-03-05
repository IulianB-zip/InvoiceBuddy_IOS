// Invoice.swift
import Foundation

enum PaymentStatus: String, Codable {
    case pending = "Pending"
    case paid = "Paid"
    case overdue = "Overdue"
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
}
