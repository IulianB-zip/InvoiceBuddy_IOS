//
//  AddInvoiceView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// AddInvoiceView.swift
import SwiftUI

struct AddInvoiceView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title = ""
    @State private var description = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    @State private var reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var selectedPaymentMethod: PaymentMethod = .creditCard
    @State private var selectedCard: Card?
    @State private var barcode: String?
    @State private var qrData: String?
    
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
            .navigationTitle("Add Invoice")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInvoice()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    init(prefillData: ScannedInvoiceData? = nil) {
        _title = State(initialValue: prefillData?.title ?? "")
        _description = State(initialValue: prefillData?.description ?? "")
        _amount = State(initialValue: prefillData?.amount != nil ? "\(prefillData!.amount!)" : "")
        _dueDate = State(initialValue: prefillData?.dueDate ?? Date())
        
        // Set reminder to 1 day before due date
        let reminderDefault = prefillData?.dueDate != nil ? 
            Calendar.current.date(byAdding: .day, value: -1, to: prefillData!.dueDate!) ?? Date() : 
            Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        _reminderDate = State(initialValue: reminderDefault)
        _barcode = State(initialValue: prefillData?.barcode)
        _qrData = State(initialValue: prefillData?.qrData)
    }
    
    private func saveInvoice() {
        guard let amountValue = Double(amount) else { return }
        
        let invoice = Invoice(
            title: title,
            description: description,
            amount: amountValue,
            dueDate: dueDate,
            status: .pending,
            paymentMethod: selectedPaymentMethod,
            reminderDate: reminderDate,
            barcode: barcode,
            qrData: qrData,
            notes: notes.isEmpty ? nil : notes,
            associatedCardId: selectedCard?.id.uuidString
        )
        
        dataManager.saveInvoice(invoice)
        presentationMode.wrappedValue.dismiss()
    }
}

