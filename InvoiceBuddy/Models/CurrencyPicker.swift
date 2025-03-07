//
//  CurrencyPicker.swift
//  InvoiceMate
//
//  Created by Iulian Bucatariu on 07.03.2025.
//

import SwiftUI

struct CurrencyPicker: View {
    @Binding var selectedCurrency: Currency
    var label: String = "Currency"
    
    var body: some View {
        Menu {
            ForEach(Currency.allCases) { currency in
                Button(action: {
                    selectedCurrency = currency
                }) {
                    HStack {
                        Text(currency.id)
                        Text(currency.rawValue)
                        
                        if currency == selectedCurrency {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                if !label.isEmpty {
                    Text(label)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(selectedCurrency.id)
                    Text(selectedCurrency.rawValue)
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// Example usage of the currency picker in an invoice form
struct InvoiceAmountRow: View {
    @Binding var amount: Double
    @Binding var currency: Currency
    @AppStorage("defaultCurrency") private var defaultCurrencyString = Currency.default.rawValue
    
    var body: some View {
        VStack {
            HStack {
                Text("Amount")
                
                Spacer()
                
                // Currency picker as an overlay next to the amount field
                Menu {
                    ForEach(Currency.allCases) { currency in
                        Button(action: {
                            self.currency = currency
                        }) {
                            HStack {
                                Text(currency.id)
                                Text(currency.rawValue)
                                
                                if currency == self.currency {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currency.id)
                            .fontWeight(.bold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
                
                // TextField for amount input
                TextField("0.00", value: $amount, formatter: currencyFormatter())
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
            
            // Preview of formatted amount
            HStack {
                Spacer()
                Text(currency.formatAmount(amount))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Helper to create a number formatter for currency input
    private func currencyFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

struct CurrencyPicker_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            CurrencyPicker(selectedCurrency: .constant(.usd))
            
            // Preview the amount row
            InvoiceAmountRow(amount: .constant(99.99), currency: .constant(.eur))
        }
    }
}
