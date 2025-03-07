//
//  Currency.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 07.03.2025.
//

import Foundation

enum Currency: String, CaseIterable, Identifiable {
    case chf = "CHF"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case ron = "RON"
    case jpy = "JPY"
    case cny = "CNY"
    case inr = "INR"
    case cad = "CAD"
    case aud = "AUD"
    case brl = "BRL"
    case mxn = "MXN"
    
    var id: String { self.rawValue }
    
    var name: String {
        switch self {
        case .chf: return "Swiss Franc"
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .ron: return "Romanian Leu"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan"
        case .inr: return "Indian Rupee"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .brl: return "Brazilian Real"
        case .mxn: return "Mexican Peso"
        }
    }
    
    static var `default`: Currency {
        return .chf
    }
    
    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = self.rawValue
        
        // Some currencies don't use decimal places
        if self == .jpy {
            formatter.maximumFractionDigits = 0
        }
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(self.rawValue) \(amount)"
    }
    
    // Get Currency from a string code, defaulting to default currency if not found
    static func from(code: String?) -> Currency {
        guard let code = code else { return .default }
        return Currency(rawValue: code) ?? .default
    }
}

struct AppSettings {
    var id: UUID
    var defaultCurrency: Currency
    
    static var defaultSettings: AppSettings {
        return AppSettings(
            id: UUID(),
            defaultCurrency: .chf
        )
    }
}
