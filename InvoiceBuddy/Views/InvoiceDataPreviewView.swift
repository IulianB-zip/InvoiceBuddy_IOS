//
//  InvoiceDataPreviewView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 07.03.2025.
//


// InvoiceDataPreviewView.swift
import SwiftUI
import AVFoundation
import Vision
import Combine


// Line Items Detail View
struct LineItemsView: View {
    let lineItems: [InvoiceLineItem]
    let currency: Currency
    
    var body: some View {
        List {
            ForEach(0..<lineItems.count, id: \.self) { index in
                let item = lineItems[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.description)
                        .font(.headline)
                    
                    HStack {
                        if let quantity = item.quantity {
                            Text("Quantity: \(quantity, specifier: "%.0f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let unitPrice = item.unitPrice {
                            Text("Unit Price: \(currency.formatAmount(unitPrice))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(currency.formatAmount(item.amount))
                            .fontWeight(.medium)
                    }
                    
                    if let vatRate = item.vatRate {
                        Text("VAT: \(vatRate, specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Total section
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total")
                        .font(.headline)
                    
                    Text(currency.formatAmount(totalAmount))
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Line Items")
    }
    
    // Calculate total
    var totalAmount: Double {
        return lineItems.reduce(0) { $0 + $1.amount }
    }
}



