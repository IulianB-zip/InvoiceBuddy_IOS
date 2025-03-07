//
//  PaymentMethodsView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// PaymentMethodsView.swift
import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddCard = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("My Cards")) {
                    ForEach(dataManager.userCards) { card in
                        CardRow(card: card)
                    }
                    .onDelete(perform: dataManager.deleteCard)
                    
                    Button(action: {
                        showingAddCard = true
                    }) {
                        Label("Add New Card", systemImage: "plus")
                    }
                }
                
                Section(header: Text("Payment Methods")) {
                    ForEach(PaymentMethod.allCases, id: \.self) { method in
                        HStack {
                            Text(method.rawValue)
                            Spacer()
                            
                            if countInvoices(using: method) > 0 {
                                Text("\(countInvoices(using: method)) invoices")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Payment Methods")
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
                    .environmentObject(dataManager)
            }
            .onAppear {
                dataManager.loadCards()
            }
        }
    }
    
    func countInvoices(using method: PaymentMethod) -> Int {
        return dataManager.invoices.filter { $0.paymentMethod == method }.count
    }
}

struct CardRow: View {
    var card: Card
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardColor)
                    .frame(width: 40, height: 25)
                
                Image(systemName: "creditcard")
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                
                Text(card.maskedNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(card.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Exp: \(card.formattedExpiryDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if card.isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(.leading, 4)
            }
        }
    }
    
    var cardColor: Color {
        switch card.type {
        case .credit:
            return .blue
        case .debit:
            return .green
        }
    }
}

struct AddCardView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var cardName = ""
    @State private var cardType: CardType = .credit
    @State private var lastFourDigits = ""
    @State private var expiryDate = Date()
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card Details")) {
                    TextField("Card Name (e.g. Chase Visa)", text: $cardName)
                    
                    Picker("Card Type", selection: $cardType) {
                        ForEach(CardType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { newValue in
                            if newValue.count > 4 {
                                lastFourDigits = String(newValue.prefix(4))
                            }
                            
                            // Filter non-numeric characters
                            lastFourDigits = newValue.filter { "0123456789".contains($0) }
                        }
                    
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                    
                    Toggle("Set as Default", isOn: $isDefault)
                }
                
                Section(footer: Text("Setting a card as default will use it for new invoices when applicable")) {
                    // Card preview
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(cardType == .credit ? Color.blue : Color.green)
                                .frame(height: 120)
                            
                            VStack {
                                HStack {
                                    Text(cardName.isEmpty ? "Card Name" : cardName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(cardType.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                HStack {
                                    Text("**** **** **** \(lastFourDigits.isEmpty ? "0000" : lastFourDigits)")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                
                                HStack {
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Expires")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Text(expiryDate.formatted(.dateTime.month(.twoDigits).year(.twoDigits)))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveCard()
                }
                .disabled(cardName.isEmpty || lastFourDigits.count < 4)
            )
        }
    }
    private func saveCard() {
        let card = Card(
            name: cardName,
            type: cardType,
            lastFourDigits: lastFourDigits,
            expiryDate: expiryDate,
            isDefault: isDefault
        )
        
        dataManager.saveCard(card)
        presentationMode.wrappedValue.dismiss()
    }
}
