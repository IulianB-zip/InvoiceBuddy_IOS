//
//  CurrencySettingsView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 07.03.2025.
//

import SwiftUI

struct CurrencySettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCurrency: Currency
    
    init() {
        // Initialize with default currency (will be updated in onAppear)
        _selectedCurrency = State(initialValue: Currency.default)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Default Currency")) {
                    ForEach(Currency.allCases) { currency in
                        Button(action: {
                            selectedCurrency = currency
                            dataManager.updateDefaultCurrency(currency)
                        }) {
                            HStack {
                                Text(currency.rawValue)
                                    .font(.title3)
                                    .frame(width: 60, alignment: .leading)
                                
                                VStack(alignment: .leading) {
                                    Text(currency.name)
                                }
                                
                                Spacer()
                                
                                if currency == selectedCurrency {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Section(header: Text("Preview")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sample Amount Formatting:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        ForEach([9.99, 99.99, 999.99, 9999.99], id: \.self) { amount in
                            HStack {
                                Text("\(amount, specifier: "%.2f")")
                                    .frame(width: 80, alignment: .leading)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text(selectedCurrency.formatAmount(amount))
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Currency Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Update selected currency when view appears
                selectedCurrency = dataManager.defaultCurrency
            }
        }
    }
}

struct CurrencySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CurrencySettingsView()
            .environmentObject(DataManager())
    }
}
