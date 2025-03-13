//
//  DetailRow.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 13.03.2025.
//


import SwiftUI

struct DetailRow: View {
    var key: String
    var value: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

struct DetailRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            DetailRow(key: "Due Date", value: "March 20, 2025")
            DetailRow(key: "Amount", value: "$123.45")
            DetailRow(key: "Payment Method", value: "Credit Card")
        }
        .previewLayout(.sizeThatFits)
    }
}