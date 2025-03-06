//
//  InvoiceManagerApp.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// InvoiceManagerApp.swift
import SwiftUI

@main
struct InvoiceManagerApp: App {
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            InvoiceListView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
                .tag(0)
            
            DashboardView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(1)
            
            ScannerView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
                .tag(2)
            
            PaymentMethodsView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Payment", systemImage: "creditcard")
                }
                .tag(3)
            
            SettingsView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
    }
}

// InvoiceListView.swift
import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddInvoice = false
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var searchText = ""
    
    enum InvoiceFilter {
        case all, pending, overdue, paid
        
        var title: String {
            switch self {
            case .all: return "All"
            case .pending: return "Pending"
            case .overdue: return "Overdue"
            case .paid: return "Paid"
            }
        }
    }
    
    var filteredInvoices: [Invoice] {
        let filtered = dataManager.invoices.filter { invoice in
            if !searchText.isEmpty {
                return invoice.title.lowercased().contains(searchText.lowercased()) ||
                       invoice.description.lowercased().contains(searchText.lowercased())
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered.sorted { $0.dueDate < $1.dueDate }
        case .pending:
            return filtered.filter { $0.status == .pending }.sorted { $0.dueDate < $1.dueDate }
        case .overdue:
            return filtered.filter { $0.status == .overdue }.sorted { $0.dueDate < $1.dueDate }
        case .paid:
            return filtered.filter { $0.status == .paid }.sorted { ($0.paymentDate ?? Date()) > ($1.paymentDate ?? Date()) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Custom filter selector
                HStack {
                    ForEach([InvoiceFilter.all, .pending, .overdue, .paid], id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter.title)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search invoices", text: $searchText)
                        .disableAutocorrection(true)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if filteredInvoices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No invoices found")
                            .font(.headline)
                        
                        if searchText.isEmpty {
                            Button(action: {
                                showingAddInvoice = true
                            }) {
                                Text("Add an invoice")
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(filteredInvoices) { invoice in
                            NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                                InvoiceRow(invoice: invoice)
                            }
                        }
                        .onDelete(perform: dataManager.deleteInvoice)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddInvoice = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                AddInvoiceView()
            }
            .onAppear {
                dataManager.loadInvoices()
            }
        }
    }
}

struct InvoiceRow: View {
    let invoice: Invoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.title)
                    .font(.headline)
                
                Text(invoice.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.formattedAmount)
                    .font(.headline)
                
                HStack {
                    Text(invoice.formattedDueDate)
                        .font(.caption)
                        .foregroundColor(dueDateColor)
                    
                    StatusIndicator(status: invoice.status)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var dueDateColor: Color {
        if invoice.status == .paid {
            return .secondary
        }
        
        let daysRemaining = invoice.daysUntilDue
        
        if daysRemaining < 0 {
            return .red
        } else if daysRemaining <= 2 {
            return .orange
        } else if daysRemaining <= 7 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct StatusIndicator: View {
    let status: PaymentStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending:
            return .blue
        case .paid:
            return .green
        case .overdue:
            return .red
        }
    }
}

// InvoiceDetailView.swift
import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @State var invoice: Invoice
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(invoice.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(invoice.description)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusIndicator(status: invoice.status)
                            .scaleEffect(1.2)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(invoice.formattedAmount)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(invoice.formattedDueDate)
                                .font(.headline)
                                .foregroundColor(invoice.isOverdue ? .red : .primary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Additional Details
                GroupBox(label: Label("Details", systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let paymentMethod = invoice.paymentMethod {
                            DetailRow(key: "Payment Method", value: paymentMethod.rawValue)
                        }
                        
                        if invoice.status == .paid, let paymentDate = invoice.paymentDate {
                            DetailRow(key: "Payment Date", value: formatDate(paymentDate))
                        }
                        
                        if let reminderDate = invoice.reminderDate {
                            DetailRow(key: "Reminder", value: formatDate(reminderDate))
                        }
                        
                        if let associatedCardId = invoice.associatedCardId, let card = findAssociatedCard(id: associatedCardId) {
                            DetailRow(key: "Card", value: "\(card.name) (\(card.lastFourDigits))")
                        }
                        
                        if let notes = invoice.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(notes)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Barcode/QR Info
                if let barcode = invoice.barcode, !barcode.isEmpty {
                    GroupBox(label: Label("Scan Data", systemImage: "barcode")) {
                        VStack(alignment: .leading) {
                            Text("Barcode/QR Data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(barcode)
                                .font(.caption)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Action Buttons
                if invoice.status != .paid {
                    Button(action: {
                        markAsPaid()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Mark as Paid")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Invoice Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        isEditing = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditInvoiceView(invoice: $invoice)
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Invoice"),
                message: Text("Are you sure you want to delete this invoice? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteInvoice()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func findAssociatedCard(id: String) -> Card? {
        return dataManager.userCards.first(where: { $0.id.uuidString == id })
    }
    
    private func markAsPaid() {
        dataManager.markInvoiceAsPaid(invoice)
        invoice.status = .paid
        invoice.isPaid = true
        invoice.paymentDate = Date()
    }
    
    private func deleteInvoice() {
        dataManager.deleteInvoice(at: [dataManager.invoices.firstIndex(where: { $0.id == invoice.id })!])
        presentationMode.wrappedValue.dismiss()
    }
}

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
                .font(.subheadline)
        }
    }
}

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