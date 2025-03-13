import SwiftUI

struct AddInvoiceView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var dataManager: DataManager
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var amount: Double = 0.0
    @State private var dueDate = Date()
    @State private var reminderDate: Date? = nil
    @State private var notes: String = ""
    @State private var priority: Int = 0
    @State private var selectedCard: Card? = nil
    @State private var selectedPaymentMethod: PaymentMethod? = nil
    @State private var selectedCurrency: Currency = .chf
    @State private var showReminderDatePicker = false
    @State private var barcode: String? = nil
    @State private var qrData: String? = nil
    
    // For validation
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    
    // Initialize with optional prefill data from scanner
    var prefillData: ScannedInvoiceData?
    
    init(prefillData: ScannedInvoiceData? = nil) {
        self.prefillData = prefillData
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invoice Details")) {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description)
                    
                    // Amount with currency
                    VStack {
                        HStack {
                            Text("Amount")
                            Spacer()
                            TextField("0.00", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        // Preview of formatted amount
                        HStack {
                            Spacer()
                            Text(selectedCurrency.formatAmount(amount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Currency picker with current styling
                    CurrencyPicker(selectedCurrency: $selectedCurrency)
                    
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
                
                Section(header: Text("Payment Details")) {
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        Text("None").tag(nil as PaymentMethod?)
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method as PaymentMethod?)
                        }
                    }
                    
                    if selectedPaymentMethod == .creditCard || selectedPaymentMethod == .debitCard {
                        Picker("Card", selection: $selectedCard) {
                            Text("None").tag(nil as Card?)
                            ForEach(dataManager.userCards) { card in
                                if (selectedPaymentMethod == .creditCard && card.type == .credit) ||
                                   (selectedPaymentMethod == .debitCard && card.type == .debit) {
                                    Text("\(card.name) (\(card.lastFourDigits))").tag(card as Card?)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Reminder")) {
                    Toggle("Set Reminder", isOn: Binding(
                        get: { reminderDate != nil },
                        set: {
                            if $0 {
                                // Default to 3 days before due date if not set
                                reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: dueDate)
                            } else {
                                reminderDate = nil
                            }
                        }
                    ))
                    
                    if reminderDate != nil {
                        DatePicker("Reminder Date", selection: Binding(
                            get: { reminderDate ?? dueDate },
                            set: { reminderDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(0)
                        Text("Medium").tag(1)
                        Text("High").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                // Only show scan data if available
                if let barcode = barcode, !barcode.isEmpty {
                    Section(header: Text("Scan Data")) {
                        Text(barcode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Invoice")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveInvoice()
                }
            )
            .onAppear {
                applyPrefillData()
            }
            .alert(isPresented: $showingValidationAlert) {
                Alert(
                    title: Text("Validation Error"),
                    message: Text(validationMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func applyPrefillData() {
        guard let data = prefillData else { return }
        
        if let title = data.title, !title.isEmpty {
            self.title = title
        }
        
        if let description = data.description, !description.isEmpty {
            self.description = description
        }
        
        if let amount = data.amount {
            self.amount = amount
        }
        
        if let dueDate = data.dueDate {
            self.dueDate = dueDate
            
            // Set default reminder 3 days before due date
            self.reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: dueDate)
        }
        
        if let barcode = data.barcode, !barcode.isEmpty {
            self.barcode = barcode
        }
        
        if let qrData = data.qrData, !qrData.isEmpty {
            self.qrData = qrData
        }
    }
    
    private func saveInvoice() {
        // Validation
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Please enter a title for this invoice."
            showingValidationAlert = true
            return
        }
        
        if amount <= 0 {
            validationMessage = "Please enter a valid amount greater than zero."
            showingValidationAlert = true
            return
        }
        
        // Create invoice object
        let invoice = Invoice(
            id: UUID(),
            title: title,
            description: description,
            amount: amount,
            dueDate: dueDate,
            status: .pending,
            paymentMethod: selectedPaymentMethod,
            reminderDate: reminderDate,
            barcode: barcode,
            qrData: qrData,
            notes: notes.isEmpty ? nil : notes,
            priority: priority,
            isPaid: false,
            paymentDate: nil,
            associatedCardId: selectedCard?.id.uuidString
        )
        
        // Save to data manager
        dataManager.saveInvoice(invoice)
        
        // Close the view
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddInvoiceView_Previews: PreviewProvider {
    static var previews: some View {
        AddInvoiceView()
            .environmentObject(DataManager())
    }
}
