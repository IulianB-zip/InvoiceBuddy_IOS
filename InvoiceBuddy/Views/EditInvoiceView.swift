//
//  EditInvoiceView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//



// EditInvoiceView.swift
import SwiftUI

struct EditInvoiceView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    @Binding var invoice: Invoice
    
    @State private var title: String
    @State private var description: String
    @State private var amount: String
    @State private var dueDate: Date
    @State private var reminderDate: Date
    @State private var notes: String
    @State private var selectedPaymentMethod: PaymentMethod
    @State private var selectedCard: Card?
    
    init(invoice: Binding<Invoice>) {
        self._invoice = invoice
        
        _title = State(initialValue: invoice.wrappedValue.title)
        _description = State(initialValue: invoice.wrappedValue.description)
        _amount = State(initialValue: String(invoice.wrappedValue.amount))
        _dueDate = State(initialValue: invoice.wrappedValue.dueDate)
        _reminderDate = State(initialValue: invoice.wrappedValue.reminderDate ?? Calendar.current.date(byAdding: .day, value: -1, to: invoice.wrappedValue.dueDate)!)
        _notes = State(initialValue: invoice.wrappedValue.notes ?? "")
        _selectedPaymentMethod = State(initialValue: invoice.wrappedValue.paymentMethod ?? .creditCard)
        
        // Find the associated card if any
        if let cardId = invoice.wrappedValue.associatedCardId {
            let cards = DataManager().userCards
            _selectedCard = State(initialValue: cards.first(where: { $0.id.uuidString == cardId }))
        } else {
            _selectedCard = State(initialValue: nil)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invoice Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Dates")) {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    DatePicker("Reminder Date", selection: $reminderDate, displayedComponents: .date)
                }
                
                Section(header: Text("Payment Method")) {
                    Picker("Method", selection: $selectedPaymentMethod) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    
                    if selectedPaymentMethod == .creditCard || selectedPaymentMethod == .debitCard {
                        Picker("Card", selection: $selectedCard) {
                            Text("Select a card").tag(nil as Card?)
                            ForEach(dataManager.userCards) { card in
                                Text("\(card.name) (\(card.lastFourDigits))").tag(card as Card?)
                            }
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Invoice")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateInvoice()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
            .onAppear {
                dataManager.loadCards()
            }
        }
    }
    
    private func updateInvoice() {
        guard let amountValue = Double(amount) else { return }
        
        var updatedInvoice = invoice
        updatedInvoice.title = title
        updatedInvoice.description = description
        updatedInvoice.amount = amountValue
        updatedInvoice.dueDate = dueDate
        updatedInvoice.reminderDate = reminderDate
        updatedInvoice.paymentMethod = selectedPaymentMethod
        updatedInvoice.notes = notes.isEmpty ? nil : notes
        updatedInvoice.associatedCardId = selectedCard?.id.uuidString
        
        dataManager.cancelNotificationForInvoice(invoice)
        dataManager.saveInvoice(updatedInvoice)
        
        invoice = updatedInvoice
        presentationMode.wrappedValue.dismiss()
    }
}
