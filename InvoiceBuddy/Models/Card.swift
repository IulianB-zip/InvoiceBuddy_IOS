//
//  Card.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// Card.swift
import Foundation

struct Card: Identifiable, Codable {
    var id = UUID()
    var name: String
    var type: CardType
    var lastFourDigits: String
    var expiryDate: Date
    var isDefault: Bool = false
}

enum CardType: String, Codable, CaseIterable {
    case credit = "Credit"
    case debit = "Debit"
}
