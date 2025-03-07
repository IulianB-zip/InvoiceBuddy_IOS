//
//  SettingsView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


//
//  DashboardView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//

// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddPayday = false
    @State private var showingMonthSettings = false
    @State private var showingCurrencySettings = false
    @State private var newPaydayDate = Date()
    @State private var showingDeleteAllConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Payment Schedule")) {
                    ForEach(dataManager.paydays.sorted(by: { $0.date < $1.date })) { payday in
                        HStack {
                            Text("Payday")
                            Spacer()
                            Text(payday.formattedDate)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        let sortedPaydays = dataManager.paydays.sorted(by: { $0.date < $1.date })
                        for index in indexSet {
                            dataManager.deletePayday(sortedPaydays[index].id)
                        }
                    }
                    
                    Button(action: {
                        showingAddPayday = true
                    }) {
                        Label("Add Payday", systemImage: "plus")
                    }
                }
                
                Section(header: Text("Month Settings")) {
                    NavigationLink(destination: MonthSettingsList()) {
                        Label("Configure Month Settings", systemImage: "calendar")
                    }
                }
                
                
                Section(header: Text("Currency")) {
                    Button(action: {
                        showingCurrencySettings = true
                    }) {
                        HStack {
                            Label("Default Currency", systemImage: "dollarsign.circle")
                            
                            Spacer()
                            
                            // Show current default currency
                            Text("\(dataManager.defaultCurrency.id)")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                
                Section(header: Text("Notifications")) {
                    Toggle("Due Date Reminders", isOn: .constant(true))
                    Toggle("Weekend Aware Reminders", isOn: .constant(true))
                }
                
                Section(header: Text("App Information")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Database")
                        Spacer()
                        Text("\(dataManager.invoices.count) invoices")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Advanced")) {
                    Button(role: .destructive, action: {
                        showingDeleteAllConfirmation = true
                    }) {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                dataManager.loadAll()
            }
            .sheet(isPresented: $showingAddPayday) {
                AddPaydayView(paydayDate: $newPaydayDate, onSave: { date in
                    let payday = Payday(date: date)
                    dataManager.savePayday(payday)
                })
            }
            .sheet(isPresented: $showingCurrencySettings) {
                CurrencySettingsView()
            }
            
            .alert("Reset All Data", isPresented: $showingDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    // This would implement a data reset function
                    // For demonstration purposes, this isn't implemented
                }
            } message: {
                Text("This will delete all invoices, cards, and settings. This action cannot be undone.")
            }
        }
    }
}

struct AddPaydayView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var paydayDate: Date
    var onSave: (Date) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Payday Date")) {
                    DatePicker("Select Date", selection: $paydayDate, displayedComponents: .date)
                }
                
                if isWeekend(paydayDate) {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("This date falls on a weekend. Most employers pay on the previous Friday for weekend paydays.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Add Payday")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(paydayDate)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7  // 1 = Sunday, 7 = Saturday
    }
}

// Some UI Extensions and Helpers for Dashboard/Settings Views

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct EmptyStateView: View {
    var message: String
    var systemImage: String
    var action: (() -> Void)?
    var actionTitle: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// Payment Prioritization Algorithm
struct PaymentPrioritizer {
    private let dataManager: DataManager
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    // Main function to prioritize and schedule payments
    func prioritizePayments() -> [PaymentSchedule] {
        let invoices = dataManager.invoices.filter { $0.status == .pending }
        let paydays = dataManager.paydays
        let monthSettings = dataManager.monthSettings
        
        if invoices.isEmpty || paydays.isEmpty {
            return []
        }
        
        // Sort invoices by due date
        let sortedInvoices = invoices.sorted { $0.dueDate < $1.dueDate }
        
        // Create payment schedules
        var paymentSchedules: [PaymentSchedule] = []
        
        // Assign invoices to paydays
        for invoice in sortedInvoices {
            // Find the best payday for this invoice
            if let bestPayday = findBestPayday(for: invoice, paydays: paydays, existingSchedules: paymentSchedules) {
                // Check if this month is critical or low income
                let isInCriticalMonth = isInCriticalOrLowIncomeMonth(date: invoice.dueDate, monthSettings: monthSettings)
                
                // Add to schedule
                let schedule = PaymentSchedule(
                    invoice: invoice,
                    paymentDate: bestPayday,
                    priority: calculatePriority(invoice: invoice, isInCriticalMonth: isInCriticalMonth)
                )
                
                paymentSchedules.append(schedule)
            }
        }
        
        // Sort schedules by payday, then by priority
        return sortSchedulesByPriorityAndDate(paymentSchedules)
    }
    
    // Find the best payday for an invoice
    private func findBestPayday(for invoice: Invoice, paydays: [Payday], existingSchedules: [PaymentSchedule]) -> Date? {
        let calendar = Calendar.current
        
        // Find paydays that are before the due date but not in the past
        let now = Date()
        let eligiblePaydays = paydays.filter { payday in
            payday.date <= invoice.dueDate && payday.date >= now
        }.map { $0.date }
        
        if eligiblePaydays.isEmpty {
            // No eligible paydays before due date, find the closest payday in the past
            let pastPaydays = paydays.filter { $0.date < invoice.dueDate }.map { $0.date }
            return pastPaydays.last
        }
        
        // Find the payday that is closest to the due date but still before it
        var bestPayday = eligiblePaydays.last!
        
        // Consider the load on each payday (how many invoices are already assigned)
        let paydayLoads = calculatePaydayLoads(existingSchedules)
        
        // If the best payday by date has too many invoices, try to find an earlier payday
        if let load = paydayLoads[bestPayday], load > 5 {
            // Look for earlier paydays with lighter loads
            for payday in eligiblePaydays.reversed().dropFirst() {
                if let currentLoad = paydayLoads[payday], currentLoad < load - 1 {
                    bestPayday = payday
                    break
                }
            }
        }
        
        return bestPayday
    }
    
    // Calculate how many invoices are already assigned to each payday
    private func calculatePaydayLoads(_ schedules: [PaymentSchedule]) -> [Date: Int] {
        var loads: [Date: Int] = [:]
        
        for schedule in schedules {
            loads[schedule.paymentDate, default: 0] += 1
        }
        
        return loads
    }
    
    // Calculate priority for an invoice
    private func calculatePriority(invoice: Invoice, isInCriticalMonth: Bool) -> Int {
        var priority = invoice.priority
        
        // Increase priority for invoices that are due soon
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: invoice.dueDate).day ?? 0
        if daysUntilDue <= 3 {
            priority += 3
        } else if daysUntilDue <= 7 {
            priority += 2
        } else if daysUntilDue <= 14 {
            priority += 1
        }
        
        // Increase priority for larger amounts
        if invoice.amount > 1000 {
            priority += 3
        } else if invoice.amount > 500 {
            priority += 2
        } else if invoice.amount > 100 {
            priority += 1
        }
        
        // Increase priority for critical months
        if isInCriticalMonth {
            priority += 2
        }
        
        return priority
    }
    
    // Check if a date falls in a critical or low income month
    private func isInCriticalOrLowIncomeMonth(date: Date, monthSettings: [MonthSetting]) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        return monthSettings.contains { setting in
            setting.year == year && setting.month == month && (setting.isCritical || setting.isLowIncome)
        }
    }
    
    // Sort payment schedules by payday and priority
    private func sortSchedulesByPriorityAndDate(_ schedules: [PaymentSchedule]) -> [PaymentSchedule] {
        return schedules.sorted { first, second in
            if first.paymentDate == second.paymentDate {
                return first.priority > second.priority // Higher priority first
            }
            return first.paymentDate < second.paymentDate // Earlier date first
        }
    }
}

// Payment Schedule struct
struct PaymentSchedule: Identifiable {
    var id = UUID()
    let invoice: Invoice
    let paymentDate: Date
    let priority: Int
    
    var isWeekendPayment: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: paymentDate)
        return weekday == 1 || weekday == 7 // 1 = Sunday, 7 = Saturday
    }
    
    var adjustedPaymentDate: Date {
        if isWeekendPayment {
            // If it's a weekend, move to Friday before
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: paymentDate)
            
            if weekday == 1 { // Sunday
                return calendar.date(byAdding: .day, value: -2, to: paymentDate)!
            } else if weekday == 7 { // Saturday
                return calendar.date(byAdding: .day, value: -1, to: paymentDate)!
            }
        }
        
        return paymentDate
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: paymentDate)
    }
}

// Extension to DataManager for payment prioritization
extension DataManager {
    func generatePaymentSchedule() -> [PaymentSchedule] {
        let prioritizer = PaymentPrioritizer(dataManager: self)
        return prioritizer.prioritizePayments()
    }
    
    // Update invoice priorities based on various factors
    func updateInvoicePriorities() {
        for i in 0..<invoices.count {
            // Base priority adjustments
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: invoices[i].dueDate).day ?? 0
            
            if daysUntilDue <= 3 {
                invoices[i].priority = max(invoices[i].priority, 5)
            } else if daysUntilDue <= 7 {
                invoices[i].priority = max(invoices[i].priority, 4)
            }
            
            // Check if in critical month
            let calendar = Calendar.current
            let year = calendar.component(.year, from: invoices[i].dueDate)
            let month = calendar.component(.month, from: invoices[i].dueDate)
            
            let isCriticalMonth = monthSettings.contains { setting in
                setting.year == year && setting.month == month && setting.isCritical
            }
            
            if isCriticalMonth {
                invoices[i].priority += 1
            }
        }
        
        // Save updated priorities
        for invoice in invoices {
            CoreDataManager.shared.updateInvoice(invoice)
        }
    }
}

struct MonthSettingsList: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddSetting = false
    
    var body: some View {
        List {
            ForEach(sortedSettings) { setting in
                NavigationLink(destination: MonthSettingDetailView(setting: setting)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(setting.displayName)
                                .font(.headline)
                            
                            HStack {
                                if setting.isCritical {
                                    Label("Critical", systemImage: "exclamationmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                if setting.isLowIncome {
                                    Label("Low Income", systemImage: "dollarsign.circle")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        if !setting.annualExpenses.isEmpty {
                            Text("\(setting.annualExpenses.count) expenses")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Button(action: {
                showingAddSetting = true
            }) {
                Label("Add Month Setting", systemImage: "plus")
            }
        }
        .navigationTitle("Month Settings")
        .sheet(isPresented: $showingAddSetting) {
            AddMonthSettingView()
        }
    }
    
    var sortedSettings: [MonthSetting] {
        return dataManager.monthSettings.sorted { setting1, setting2 in
            if setting1.year != setting2.year {
                return setting1.year < setting2.year
            } else {
                return setting1.month < setting2.month
            }
        }
    }
}

struct MonthSettingDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    var setting: MonthSetting
    @State private var showingEditSetting = false
    @State private var showingAddExpense = false
    
    var body: some View {
        List {
            Section(header: Text("Month Status")) {
                HStack {
                    Text("Critical Month")
                    Spacer()
                    Image(systemName: setting.isCritical ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(setting.isCritical ? .red : .secondary)
                }
                
                HStack {
                    Text("Low Income Month")
                    Spacer()
                    Image(systemName: setting.isLowIncome ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(setting.isLowIncome ? .orange : .secondary)
                }
                
                if let note = setting.note, !note.isEmpty {
                    Text("Note: \(note)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Annual Expenses")) {
                ForEach(setting.annualExpenses) { expense in
                    VStack(alignment: .leading) {
                        Text(expense.title)
                            .font(.headline)
                        
                        HStack {
                            Text(expense.formattedAmount)
                            Spacer()
                            Text("Due: \(expense.formattedDueDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(action: {
                    showingAddExpense = true
                }) {
                    Label("Add Annual Expense", systemImage: "plus")
                }
            }
            
            // Related invoices section
            Section(header: Text("Related Invoices")) {
                let relatedInvoices = getRelatedInvoices()
                
                if relatedInvoices.isEmpty {
                    Text("No invoices for this month")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(relatedInvoices) { invoice in
                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(invoice.title)
                                        .font(.headline)
                                    
                                    Text(invoice.formattedDueDate)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(invoice.formattedAmount)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(setting.displayName)
        .toolbar {
            Button(action: {
                showingEditSetting = true
            }) {
                Text("Edit")
            }
        }
        .sheet(isPresented: $showingEditSetting) {
            EditMonthSettingView(setting: setting)
        }
        .sheet(isPresented: $showingAddExpense) {
            AddAnnualExpenseView { expense in
                var updatedSetting = setting
                updatedSetting.annualExpenses.append(expense)
                dataManager.saveMonthSetting(updatedSetting)
            }
        }
    }
    
    private func getRelatedInvoices() -> [Invoice] {
        return dataManager.getInvoicesForMonth(month: setting.month, year: setting.year)
    }
}

struct AddMonthSettingView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var isCritical = false
    @State private var isLowIncome = false
    @State private var note = ""
    @State private var annualExpenses: [AnnualExpense] = []
    @State private var showingAddExpense = false
    @State private var showingDuplicateWarning = false
    
    var monthsArray = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
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
                        ForEach(0..<monthsArray.count, id: \.self) { index in
                            Text(monthsArray[index]).tag(index + 1)
                        }
                    }
                }
                
                Section(header: Text("Month Status")) {
                    Toggle("Critical Month", isOn: $isCritical)
                    Toggle("Low Income Month", isOn: $isLowIncome)
                    
                    if isCritical || isLowIncome {
                        TextField("Note (optional)", text: $note)
                    }
                }
                
                Section(header: Text("Annual Expenses")) {
                    ForEach(annualExpenses) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.title)
                                .font(.headline)
                            
                            HStack {
                                Text(expense.formattedAmount)
                                Spacer()
                                Text("Due: \(expense.formattedDueDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        annualExpenses.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: {
                        showingAddExpense = true
                    }) {
                        Label("Add Annual Expense", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Add Month Setting")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        checkAndSaveMonthSetting()
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddAnnualExpenseView { expense in
                    annualExpenses.append(expense)
                }
            }
            .alert("Month Setting Already Exists", isPresented: $showingDuplicateWarning) {
                Button("Cancel", role: .cancel) { }
                Button("Replace", role: .destructive) {
                    saveMonthSetting(overwrite: true)
                }
            } message: {
                Text("A setting for \(monthsArray[selectedMonth-1]) \(selectedYear) already exists. Do you want to replace it?")
            }
        }
    }
    
    private func checkAndSaveMonthSetting() {
        // Check if a setting already exists for this month/year
        let existingSetting = dataManager.monthSettings.first { setting in
            setting.year == selectedYear && setting.month == selectedMonth
        }
        
        if existingSetting != nil {
            showingDuplicateWarning = true
        } else {
            saveMonthSetting(overwrite: false)
        }
    }
    
    private func saveMonthSetting(overwrite: Bool) {
        // If overwriting, we might want to keep the existing ID
        let existingSetting = dataManager.monthSettings.first { setting in
            setting.year == selectedYear && setting.month == selectedMonth
        }
        
        let setting = MonthSetting(
            id: overwrite ? existingSetting?.id ?? UUID() : UUID(),
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
}

struct EditMonthSettingView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    var setting: MonthSetting
    
    @State private var isCritical: Bool
    @State private var isLowIncome: Bool
    @State private var note: String
    @State private var annualExpenses: [AnnualExpense]
    @State private var showingAddExpense = false
    
    init(setting: MonthSetting) {
        self.setting = setting
        
        _isCritical = State(initialValue: setting.isCritical)
        _isLowIncome = State(initialValue: setting.isLowIncome)
        _note = State(initialValue: setting.note ?? "")
        _annualExpenses = State(initialValue: setting.annualExpenses)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Month Status")) {
                    Toggle("Critical Month", isOn: $isCritical)
                    Toggle("Low Income Month", isOn: $isLowIncome)
                    
                    if isCritical || isLowIncome {
                        TextField("Note (optional)", text: $note)
                    }
                }
                
                Section(header: Text("Annual Expenses")) {
                    ForEach(annualExpenses) { expense in
                        VStack(alignment: .leading) {
                            Text(expense.title)
                                .font(.headline)
                            
                            HStack {
                                Text(expense.formattedAmount)
                                Spacer()
                                Text("Due: \(expense.formattedDueDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        annualExpenses.remove(atOffsets: indexSet)
                    }
                    
                    Button(action: {
                        showingAddExpense = true
                    }) {
                        Label("Add Annual Expense", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit \(setting.displayName)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateMonthSetting()
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
    
    private func updateMonthSetting() {
        var updatedSetting = setting
        updatedSetting.isCritical = isCritical
        updatedSetting.isLowIncome = isLowIncome
        updatedSetting.note = note.isEmpty ? nil : note
        updatedSetting.annualExpenses = annualExpenses
        
        dataManager.saveMonthSetting(updatedSetting)
        presentationMode.wrappedValue.dismiss()
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
