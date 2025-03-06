//
//  CardType.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Card.swift
import Foundation

enum CardType: String, Codable, CaseIterable {
    case credit = "Credit"
    case debit = "Debit"
}

struct Card: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: CardType
    var lastFourDigits: String
    var expiryDate: Date
    var isDefault: Bool = false

    var formattedExpiryDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: expiryDate)
    }
    
    var maskedNumber: String {
        return "**** **** **** \(lastFourDigits)"
    }


    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
