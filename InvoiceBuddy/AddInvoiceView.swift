//
//  AddInvoiceView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
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
    @State private var reminderDate = Date()
    @State private var notes = ""
    @State private var selectedPaymentMethod: PaymentMethod = .creditCard
    @State private var selectedCard: Card?
    @State private var prefillDataString: String?
    
    init(prefillData: String? = nil) {
        self._prefillDataString = State(initialValue: prefillData)
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
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(dataManager.paymentMethods, id: \.self) { method in
                            Text(method.rawValue)
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
                        .frame(height: 100)
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
            .onAppear {
                processPrefillData()
            }
        }
    }
    
    private func processPrefillData() {
        guard let data = prefillDataString else { return }
        
        // This is a placeholder for processing QR/barcode data
        // In a real app, you would parse the data according to the expected format
        
        // Example of a simple key-value format: "title=Electric Bill&amount=75.50&due=2023-04-15"
        let components = data.components(separatedBy: "&")
        
        for component in components {
            let keyValue = component.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0]
                let value = keyValue[1]
                
                switch key {
                case "title":
                    title = value
                case "description":
                    description = value
                case "amount":
                    amount = value
                case "due":
                    if let date = ISO8601DateFormatter().date(from: value) {
                        dueDate = date
                        // Set reminder to 1 day before
                        reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    }
                default:
                    break
                }
            }
        }
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
            barcode: prefillDataString,
            notes: notes,
            associatedCardId: selectedCard?.id.uuidString
        )
        
        dataManager.saveInvoice(invoice)
        presentationMode.wrappedValue.dismiss()
    }
}

// DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Upcoming Invoices Card
                    dashboardCard(title: "Upcoming Invoices") {
                        upcomingInvoicesView
                    }
                    
                    // Total Due This Month
                    dashboardCard(title: "This Month") {
                        monthTotalsView
                    }
                    
                    // Payment Methods Distribution
                    dashboardCard(title: "Payment Methods") {
                        paymentMethodsDistributionView
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
    
    @ViewBuilder
    private func dashboardCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            content()
                .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var upcomingInvoicesView: some View {
        VStack(spacing: 12) {
            ForEach(upcomingInvoices.prefix(3)) { invoice in
                HStack {
                    VStack(alignment: .leading) {
                        Text(invoice.title)
                            .font(.subheadline)
                        Text(formattedDate(invoice.dueDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", invoice.amount))")
                        .font(.subheadline)
                        .bold()
                }
                .padding(.horizontal)
                
                if upcomingInvoices.prefix(3).last?.id != invoice.id {
                    Divider()
                        .padding(.horizontal)
                }
            }
            
            if upcomingInvoices.isEmpty {
                Text("No upcoming invoices")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    private var monthTotalsView: some View {
        HStack(spacing: 20) {
            VStack {
                Text("$\(String(format: "%.2f", totalDueThisMonth))")
                    .font(.title2)
                    .bold()
                Text("Total Due")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("\(pendingThisMonth)")
                    .font(.title2)
                    .bold()
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .frame(height: 40)
            
            VStack {
                Text("\(paidThisMonth)")
                    .font(.title2)
                    .bold()
                Text("Paid")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private var paymentMethodsDistributionView: some View {
        HStack(spacing: 15) {
            ForEach(paymentMethodDistribution.keys.sorted(), id: \.self) { method in
                VStack {
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 4)
                            .opacity(0.3)
                            .foregroundColor(colorForPaymentMethod(method))
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(paymentMethodDistribution[method]! / 100))
                            .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            .foregroundColor(colorForPaymentMethod(method))
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: paymentMethodDistribution[method]!)
                        
                        Text("\(Int(paymentMethodDistribution[method]!))%")
                            .font(.caption)
                            .bold()
                    }
                    .frame(width: 50, height: 50)
                    
                    Text(method.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    // Helper methods
    private var upcomingInvoices: [Invoice] {
        let currentDate = Date()
        return dataManager.invoices
            .filter { $0.dueDate >= currentDate && $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private var totalDueThisMonth: Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return dataManager.invoices
            .filter { invoice in
                let month = calendar.component(.month, from: invoice.dueDate)
                let year = calendar.component(.year, from: invoice.dueDate)
                return month == currentMonth && year == currentYear && invoice.status != .paid
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var pendingThisMonth: Int {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return dataManager.invoices
            .filter { invoice in
                let month = calendar.component(.month, from: invoice.dueDate)
                let year = calendar.component(.year, from: invoice.dueDate)
                return month == currentMonth && year == currentYear && invoice.status == .pending
            }
            .count
    }
    
    private var paidThisMonth: Int {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return dataManager.invoices
            .filter { invoice in
                let month = calendar.component(.month, from: invoice.dueDate)
                let year = calendar.component(.year, from: invoice.dueDate)
                return month == currentMonth && year == currentYear && invoice.status == .paid
            }
            .count
    }
    
    private var paymentMethodDistribution: [PaymentMethod: Double] {
        var distribution: [PaymentMethod: Int] = [:]
        let totalInvoices = dataManager.invoices.count
        
        for invoice in dataManager.invoices {
            if let method = invoice.paymentMethod {
                distribution[method, default: 0] += 1
            }
        }
        
        var percentages: [PaymentMethod: Double] = [:]
        for (method, count) in distribution {
            percentages[method] = Double(count) / Double(totalInvoices) * 100
        }
        
        return percentages
    }
    
    private func colorForPaymentMethod(_ method: PaymentMethod) -> Color {
        switch method {
        case .creditCard:
            return .blue
        case .debitCard:
            return .green
        case .bankTransfer:
            return .purple
        case .cash:
            return .orange
        case .other:
            return .gray
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

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
                    ForEach(dataManager.paymentMethods, id: \.self) { method in
                        Text(method.rawValue)
                    }
                }
            }
            .navigationTitle("Payment Methods")
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
                    .environmentObject(dataManager)
            }
        }
    }
}

struct CardRow: View {
    var card: Card
    
    var body: some View {
        HStack {
            Image(systemName: card.type == .credit ? "creditcard" : "creditcard.fill")
                .foregroundColor(card.type == .credit ? .blue : .green)
            
            VStack(alignment: .leading) {
                Text(card.name)
                    .font(.headline)
                Text("**** **** **** \(card.lastFourDigits)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(card.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(expiryDateFormatted(card.expiryDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if card.isDefault {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func expiryDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: date)
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
                    TextField("Card Name", text: $cardName)
                    
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
                        }
                    
                    DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                    
                    Toggle("Set as Default", isOn: $isDefault)
                }
            }
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .disabled(cardName.isEmpty || lastFourDigits.count < 4)
                }
            }
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

// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingMonthSettings = false
    @State private var paydays: [Date] = [Date()]
    @State private var showingAddPayday = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Payment Schedule")) {
                    ForEach(paydays.indices, id: \.self) { index in
                        DatePicker("Payday \(index + 1)", selection: $paydays[index], displayedComponents: .date)
                    }
                    .onDelete { indexSet in
                        paydays.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Payday") {
                        showingAddPayday = true
                    }
                }
                
                Section(header: Text("Month Settings")) {
                    Button("Configure Month Settings") {
                        showingMonthSettings = true
                    }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Due Date Reminders", isOn: .constant(true))
                    Toggle("Weekend Aware Reminders", isOn: .constant(true))
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingMonthSettings) {
                MonthSettingsView()
                    .environmentObject(dataManager)
            }
            .alert(isPresented: $showingAddPayday) {
                Alert(
                    title: Text("Add Payday"),
                    message: Text("This will add a new payday to your schedule."),
                    primaryButton: .default(Text("Add")) {
                        paydays.append(Date())
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

struct MonthSettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var isCritical = false
    @State private var isLowIncome = false
    @State private var note = ""
    @State private var annualExpenses: [AnnualExpense] = []
    @State private var showingAddExpense = false
    
    var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Month")) {
                    Picker("Year", selection: $selectedYear) {
                        ForEach(Calendar.current.component(.year, from: Date())-1...Calendar.current.component(.year, from: Date())+5, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(months[month-1]).tag(month)
                        }
                    }
                }
                
                Section(header: Text("Month Status")) {
                    Toggle("Critical Month", isOn: $isCritical)
                    Toggle("Low Income Month", isOn: $isLowIncome)
                    
                    if isCritical || isLowIncome {
                        TextField("Note", text: $note)
                    }
                }
                
                Section(header: Text("Annual Expenses")) {
                    ForEach(annualExpenses) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.title)
                                .font(.headline)
                            HStack {
                                Text("$\(String(format: "%.2f", expense.amount))")
                                Spacer()
                                Text(formattedDate(expense.dueDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        annualExpenses.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Annual Expense") {
                        showingAddExpense = true
                    }
                }
            }
            .navigationTitle("Month Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMonthSetting()
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddAnnualExpenseView { expense in
                    annualExpenses.append(expense)
                }
            }
        }
    }
    
    private func saveMonthSetting() {
        let setting = MonthSetting(
            year: selectedYear,
            month: selectedMonth,
            isCritical: isCritical,
            isLowIncome: isLowIncome,
            note: note.isEmpty ? nil : note,
            annualExpenses: annualExpenses
        )
        
        dataManager.saveMonthSetting(setting)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct AddAnnualExpenseView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title = ""
    @State private var amount = ""
    @State private var dueDate = Date()
    
    var onSave: (AnnualExpense) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Annual Expense")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(title.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount) else { return }
        
        let expense = AnnualExpense(
            title: title,
            amount: amountValue,
            dueDate: dueDate
        )
        
        onSave(expense)
        presentationMode.wrappedValue.dismiss()
    }
}