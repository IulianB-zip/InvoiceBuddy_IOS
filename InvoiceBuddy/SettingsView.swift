//
//  SettingsView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Settings View Implementation

import SwiftUI
import Combine

struct SettingsView: View {
    @State private var showingMonthSettings = false
    @State private var showingAddPayday = false
    @State private var paydays: [Date] = []
    @State private var newPaydayDate = Date()
    @State private var notificationsEnabled = true
    @State private var weekendAwareReminders = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let paydayService: PaydayService
    private let notificationService: NotificationService
    
    init(
        paydayService: PaydayService = PaydayRepository(persistenceController: PersistenceController.shared),
        notificationService: NotificationService = UNNotificationService()
    ) {
        self.paydayService = paydayService
        self.notificationService = notificationService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Payment Schedule")) {
                        if paydays.isEmpty {
                            Text("No paydays scheduled")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(paydays.indices, id: \.self) { index in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                    
                                    Text(formattedDate(paydays[index]))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        deletePayday(paydays[index])
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            showingAddPayday = true
                        }) {
                            Label("Add Payday", systemImage: "plus")
                        }
                    }
                    
                    Section(header: Text("Month Settings")) {
                        NavigationLink(destination: MonthSettingsListView()) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.blue)
                                Text("Configure Month Settings")
                            }
                        }
                    }
                    
                    Section(header: Text("Notifications")) {
                        Toggle("Due Date Reminders", isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { newValue in
                                if newValue {
                                    requestNotificationPermissions()
                                }
                            }
                        
                        if notificationsEnabled {
                            Toggle("Weekend-Aware Reminders", isOn: $weekendAwareReminders)
                                .onChange(of: weekendAwareReminders) { _ in
                                    // You could store this preference in UserDefaults
                                    UserDefaults.standard.set(weekendAwareReminders, forKey: "weekendAwareReminders")
                                }
                        }
                    }
                    
                    Section(header: Text("About")) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                            Text("Privacy Policy")
                        }
                        
                        Button("Reset All Data") {
                            // Show confirmation dialog
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Settings")
                .sheet(isPresented: $showingAddPayday) {
                    AddPaydayView(
                        paydayDate: $newPaydayDate,
                        onSave: savePayday
                    )
                }
                .onAppear {
                    loadPaydays()
                    weekendAwareReminders = UserDefaults.standard.bool(forKey: "weekendAwareReminders")
                }
                .refreshable {
                    loadPaydays()
                }
                .overlay {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
                
                if let errorMessage = errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
        }
    }
    
    private func loadPaydays() {
        isLoading = true
        errorMessage = nil
        
        paydayService.fetchPaydays()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { fetchedPaydays in
                self.paydays = fetchedPaydays.sorted()
            }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func savePayday() {
        isLoading = true
        errorMessage = nil
        
        paydayService.savePayday(newPaydayDate)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    loadPaydays()
                }
            } receiveValue: { _ in }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func deletePayday(_ date: Date) {
        isLoading = true
        errorMessage = nil
        
        paydayService.deletePayday(date: date)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    loadPaydays()
                }
            } receiveValue: { _ in }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func requestNotificationPermissions() {
        notificationService.requestPermissions()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    errorMessage = "Failed to request notification permissions: \(error.localizedDescription)"
                    notificationsEnabled = false
                }
            } receiveValue: { granted in
                if !granted {
                    errorMessage = "Please enable notifications in Settings to receive reminders"
                    notificationsEnabled = false
                }
            }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct AddPaydayView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var paydayDate: Date
    var onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Payday Date")) {
                    DatePicker("Date", selection: $paydayDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                
                Section {
                    Button(action: {
                        onSave()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Save Payday")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Add Payday")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct MonthSettingsListView: View {
    @State private var monthSettings: [MonthSetting] = []
    @State private var showingAddMonthSetting = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let monthSettingService: MonthSettingService
    
    init(monthSettingService: MonthSettingService = MonthSettingRepository(persistenceController: PersistenceController.shared)) {
        self.monthSettingService = monthSettingService
    }
    
    var body: some View {
        ZStack {
            List {
                ForEach(monthSettings.sorted { ($0.year, $0.month) < ($1.year, $1.month) }) { setting in
                    NavigationLink(destination: EditMonthSettingView(monthSetting: setting, onSave: {
                        loadMonthSettings()
                    })) {
                        MonthSettingRow(setting: setting)
                    }
                }
                .onDelete(perform: deleteMonthSettings)
            }
            .navigationTitle("Month Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddMonthSetting = true
                    }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMonthSetting) {
                AddMonthSettingView(onSave: {
                    loadMonthSettings()
                })
            }
            .refreshable {
                loadMonthSettings()
            }
            .onAppear {
                loadMonthSettings()
            }
            .overlay {
                if monthSettings.isEmpty && !isLoading {
                    ContentUnavailableView(
                        label: {
                            Label("No Month Settings", systemImage: "calendar")
                        },
                        description: {
                            Text("Add month settings to manage special months")
                        },
                        actions: {
                            Button(action: { showingAddMonthSetting = true }) {
                                Text("Add Month Setting")
                            }
                            .buttonStyle(.bordered)
                        }
                    )
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            
            if let errorMessage = errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
    }
    
    private func loadMonthSettings() {
        isLoading = true
        errorMessage = nil
        
        monthSettingService.fetchMonthSettings()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { settings in
                self.monthSettings = settings
            }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func deleteMonthSettings(at offsets: IndexSet) {
        let sortedSettings = monthSettings.sorted { ($0.year, $0.month) < ($1.year, $1.month) }
        
        for index in offsets {
            let setting = sortedSettings[index]
            
            monthSettingService.deleteMonthSetting(id: setting.id)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    } else {
                        loadMonthSettings()
                    }
                } receiveValue: { _ in }
                .store(in: &Set<AnyCancellable>())
        }
    }
}

struct MonthSettingRow: View {
    var setting: MonthSetting
    
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(months[setting.month - 1]) \(setting.year)")
                    .font(.headline)
                
                HStack {
                    if setting.isCritical {
                        Label("Critical", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if setting.isLowIncome {
                        Label("Low Income", systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                if let note = setting.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if !setting.annualExpenses.isEmpty {
                VStack(alignment: .trailing) {
                    Text("\(setting.annualExpenses.count) expenses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(String(format: "%.2f", setting.annualExpenses.reduce(0) { $0 + $1.amount }))")
                        .font(.subheadline)
                        .bold()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddMonthSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var isCritical = false
    @State private var isLowIncome = false
    @State private var note = ""
    @State private var annualExpenses: [AnnualExpense] = []
    @State private var showingAddExpense = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let monthSettingService: MonthSettingService
    private let onSave: () -> Void
    
    init(
        monthSettingService: MonthSettingService = MonthSettingRepository(persistenceController: PersistenceController.shared),
        onSave: @escaping () -> Void
    ) {
        self.monthSettingService = monthSettingService
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ZStack {
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
                                        .font(.subheadline)
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
                .navigationTitle("Add Month Setting")
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
                        .disabled(isLoading)
                    }
                }
                .sheet(isPresented: $showingAddExpense) {
                    AddAnnualExpenseView { expense in
                        annualExpenses.append(expense)
                    }
                }
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
                
                if let errorMessage = errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
        }
    }
    
    private func saveMonthSetting() {
        isLoading = true
        errorMessage = nil
        
        let setting = MonthSetting(
            year: selectedYear,
            month: selectedMonth,
            isCritical: isCritical,
            isLowIncome: isLowIncome,
            note: note.isEmpty ? nil : note,
            annualExpenses: annualExpenses
        )
        
        monthSettingService.saveMonthSetting(setting)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            } receiveValue: { _ in }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct EditMonthSettingView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var isCritical: Bool
    @State private var isLowIncome: Bool
    @State private var note: String
    @State private var annualExpenses: [AnnualExpense]
    @State private var showingAddExpense = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private let monthSettingService: MonthSettingService
    private let onSave: () -> Void
    private let originalSetting: MonthSetting
    
    init(
        monthSetting: MonthSetting,
        monthSettingService: MonthSettingService = MonthSettingRepository(persistenceController: PersistenceController.shared),
        onSave: @escaping () -> Void
    ) {
        self.originalSetting = monthSetting
        self.monthSettingService = monthSettingService
        self.onSave = onSave
        
        _selectedYear = State(initialValue: monthSetting.year)
        _selectedMonth = State(initialValue: monthSetting.month)
        _isCritical = State(initialValue: monthSetting.isCritical)
        _isLowIncome = State(initialValue: monthSetting.isLowIncome)
        _note = State(initialValue: monthSetting.note ?? "")
        _annualExpenses = State(initialValue: monthSetting.annualExpenses)
    }
    
    var body: some View {
        ZStack {
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
                                    .font(.subheadline)
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
            .navigationTitle("Edit Month Setting")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMonthSetting()
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddAnnualExpenseView { expense in
                    annualExpenses.append(expense)
                }
            }
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            }
            
            if let errorMessage = errorMessage {
                ErrorBanner(message: errorMessage)
            }
        }
    }
    
    private func saveMonthSetting() {
        isLoading = true
        errorMessage = nil
        
        var updatedSetting = originalSetting
        updatedSetting.year = selectedYear
        updatedSetting.month = selectedMonth
        updatedSetting.isCritical = isCritical
        updatedSetting.isLowIncome = isLowIncome
        updatedSetting.note = note.isEmpty ? nil : note
        updatedSetting.annualExpenses = annualExpenses
        
        monthSettingService.saveMonthSetting(updatedSetting)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    onSave()
                    presentationMode.wrappedValue.dismiss()
                }
            } receiveValue: { _ in }
            .store(in: &Set<AnyCancellable>())
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
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else { return }
        
        let expense = AnnualExpense(
            title: title,
            amount: amountValue,
            dueDate: dueDate
        )
        
        onSave(expense)
        presentationMode.wrappedValue.dismiss()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .bold()
                
                Group {
                    Text("InvoiceBuddy is designed with your privacy in mind. We do not collect any personal data from you.")
                        .font(.headline)
                    
                    Text("Data Storage")
                        .font(.title2)
                        .bold()
                    
                    Text("All your invoice and payment data is stored locally on your device using Apple's Core Data framework. We do not upload or transmit your financial information to any external servers.")
                    
                    Text("Notifications")
                        .font(.title2)
                        .bold()
                    
                    Text("When you enable notifications, they are handled by the iOS system and are only used to remind you about upcoming invoices. No notification data is collected or analyzed.")
                    
                    Text("Camera Access")
                        .font(.title2)
                        .bold()
                    
                    Text("We request camera access solely for the purpose of scanning invoice barcodes or QR codes. No photos or videos are stored or transmitted.")
                    
                    Text("Changes to This Policy")
                        .font(.title2)
                        .bold()
                    
                    Text("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.")
                }
                
                Spacer(minLength: 40)
                
                Text("Last updated: March 6, 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}