//
//  CoreDataManager.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// CoreDataManager.swift
import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let persistentContainer: NSPersistentContainer
    
    init() {
        persistentContainer = NSPersistentContainer(name: "InvoiceManager")
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Core Data Context
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving Core Data context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Invoice Methods
    
    func saveInvoice(_ invoice: Invoice) {
        let context = persistentContainer.viewContext
        
        let invoiceEntity = InvoiceEntity(context: context)
        invoiceEntity.id = invoice.id
        invoiceEntity.title = invoice.title
        invoiceEntity.invoiceDescription = invoice.description
        invoiceEntity.amount = invoice.amount
        invoiceEntity.dueDate = invoice.dueDate
        invoiceEntity.status = invoice.status.rawValue
        invoiceEntity.paymentMethod = invoice.paymentMethod?.rawValue
        invoiceEntity.reminderDate = invoice.reminderDate
        invoiceEntity.barcode = invoice.barcode
        invoiceEntity.qrData = invoice.qrData
        invoiceEntity.notes = invoice.notes
        invoiceEntity.priority = Int16(invoice.priority)
        invoiceEntity.isPaid = invoice.isPaid
        invoiceEntity.paymentDate = invoice.paymentDate
        invoiceEntity.associatedCardId = invoice.associatedCardId
        
        do {
            try context.save()
        } catch {
            print("Failed to save invoice: \(error.localizedDescription)")
        }
    }
    
    func fetchInvoices() -> [Invoice] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
        
        do {
            let invoiceEntities = try context.fetch(fetchRequest)
            return invoiceEntities.map { entity in
                Invoice(
                    id: entity.id ?? UUID(),
                    title: entity.title ?? "",
                    description: entity.invoiceDescription ?? "",
                    amount: entity.amount,
                    dueDate: entity.dueDate ?? Date(),
                    status: PaymentStatus(rawValue: entity.status ?? "") ?? .pending,
                    paymentMethod: entity.paymentMethod.flatMap { PaymentMethod(rawValue: $0) },
                    reminderDate: entity.reminderDate,
                    barcode: entity.barcode,
                    qrData: entity.qrData,
                    notes: entity.notes,
                    priority: Int(entity.priority),
                    isPaid: entity.isPaid,
                    paymentDate: entity.paymentDate,
                    associatedCardId: entity.associatedCardId
                )
            }
        } catch {
            print("Failed to fetch invoices: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteInvoice(id: UUID) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let invoiceEntity = results.first {
                context.delete(invoiceEntity)
                try context.save()
            }
        } catch {
            print("Failed to delete invoice: \(error.localizedDescription)")
        }
    }
    
    func updateInvoice(_ invoice: Invoice) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", invoice.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let invoiceEntity = results.first {
                invoiceEntity.title = invoice.title
                invoiceEntity.invoiceDescription = invoice.description
                invoiceEntity.amount = invoice.amount
                invoiceEntity.dueDate = invoice.dueDate
                invoiceEntity.status = invoice.status.rawValue
                invoiceEntity.paymentMethod = invoice.paymentMethod?.rawValue
                invoiceEntity.reminderDate = invoice.reminderDate
                invoiceEntity.barcode = invoice.barcode
                invoiceEntity.qrData = invoice.qrData
                invoiceEntity.notes = invoice.notes
                invoiceEntity.priority = Int16(invoice.priority)
                invoiceEntity.isPaid = invoice.isPaid
                invoiceEntity.paymentDate = invoice.paymentDate
                invoiceEntity.associatedCardId = invoice.associatedCardId
                
                try context.save()
            }
        } catch {
            print("Failed to update invoice: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Card Methods
    
    func saveCard(_ card: Card) {
        let context = persistentContainer.viewContext
        
        // If this is the default card, unset default on other cards
        if card.isDefault {
            unsetDefaultCards()
        }
        
        let cardEntity = CardEntity(context: context)
        cardEntity.id = card.id
        cardEntity.name = card.name
        cardEntity.type = card.type.rawValue
        cardEntity.lastFourDigits = card.lastFourDigits
        cardEntity.expiryDate = card.expiryDate
        cardEntity.isDefault = card.isDefault
        
        do {
            try context.save()
        } catch {
            print("Failed to save card: \(error.localizedDescription)")
        }
    }
    
    private func unsetDefaultCards() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isDefault == %@", NSNumber(value: true))
        
        do {
            let results = try context.fetch(fetchRequest)
            for cardEntity in results {
                cardEntity.isDefault = false
            }
            try context.save()
        } catch {
            print("Failed to unset default cards: \(error.localizedDescription)")
        }
    }
    
    func fetchCards() -> [Card] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        
        do {
            let cardEntities = try context.fetch(fetchRequest)
            return cardEntities.map { entity in
                Card(
                    id: entity.id ?? UUID(),
                    name: entity.name ?? "",
                    type: CardType(rawValue: entity.type ?? "") ?? .credit,
                    lastFourDigits: entity.lastFourDigits ?? "",
                    expiryDate: entity.expiryDate ?? Date(),
                    isDefault: entity.isDefault
                )
            }
        } catch {
            print("Failed to fetch cards: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteCard(id: UUID) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let cardEntity = results.first {
                context.delete(cardEntity)
                try context.save()
            }
        } catch {
            print("Failed to delete card: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Month Settings Methods
    
    func saveMonthSetting(_ monthSetting: MonthSetting) {
        let context = persistentContainer.viewContext
        
        // Check if setting for this month already exists
        let existingSettings = fetchMonthSetting(year: monthSetting.year, month: monthSetting.month)
        
        if let existingSetting = existingSettings.first {
            // Update existing setting
            updateMonthSetting(existingSetting.id, with: monthSetting)
            return
        }
        
        // Create new setting
        let settingEntity = MonthSettingEntity(context: context)
        settingEntity.id = monthSetting.id
        settingEntity.year = Int16(monthSetting.year)
        settingEntity.month = Int16(monthSetting.month)
        settingEntity.isCritical = monthSetting.isCritical
        settingEntity.isLowIncome = monthSetting.isLowIncome
        settingEntity.note = monthSetting.note
        
        // Save annual expenses
        for expense in monthSetting.annualExpenses {
            let expenseEntity = AnnualExpenseEntity(context: context)
            expenseEntity.id = expense.id
            expenseEntity.title = expense.title
            expenseEntity.amount = expense.amount
            expenseEntity.dueDate = expense.dueDate
            expenseEntity.monthSetting = settingEntity
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save month setting: \(error.localizedDescription)")
        }
    }
    
    func fetchMonthSettings() -> [MonthSetting] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { entity in
                let annualExpenses = (entity.annualExpenses?.allObjects as? [AnnualExpenseEntity])?.map { expenseEntity in
                    AnnualExpense(
                        id: expenseEntity.id ?? UUID(),
                        title: expenseEntity.title ?? "",
                        amount: expenseEntity.amount,
                        dueDate: expenseEntity.dueDate ?? Date()
                    )
                } ?? []
                
                return MonthSetting(
                    id: entity.id ?? UUID(),
                    year: Int(entity.year),
                    month: Int(entity.month),
                    isCritical: entity.isCritical,
                    isLowIncome: entity.isLowIncome,
                    note: entity.note,
                    annualExpenses: annualExpenses
                )
            }
        } catch {
            print("Failed to fetch month settings: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchMonthSetting(year: Int, month: Int) -> [MonthSetting] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "year == %d AND month == %d", year, month)
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { entity in
                let annualExpenses = (entity.annualExpenses?.allObjects as? [AnnualExpenseEntity])?.map { expenseEntity in
                    AnnualExpense(
                        id: expenseEntity.id ?? UUID(),
                        title: expenseEntity.title ?? "",
                        amount: expenseEntity.amount,
                        dueDate: expenseEntity.dueDate ?? Date()
                    )
                } ?? []
                
                return MonthSetting(
                    id: entity.id ?? UUID(),
                    year: Int(entity.year),
                    month: Int(entity.month),
                    isCritical: entity.isCritical,
                    isLowIncome: entity.isLowIncome,
                    note: entity.note,
                    annualExpenses: annualExpenses
                )
            }
        } catch {
            print("Failed to fetch month setting: \(error.localizedDescription)")
            return []
        }
    }
    
    private func updateMonthSetting(_ id: UUID, with monthSetting: MonthSetting) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let entity = results.first {
                entity.year = Int16(monthSetting.year)
                entity.month = Int16(monthSetting.month)
                entity.isCritical = monthSetting.isCritical
                entity.isLowIncome = monthSetting.isLowIncome
                entity.note = monthSetting.note
                
                // Delete existing expenses
                if let expenses = entity.annualExpenses {
                    for case let expense as AnnualExpenseEntity in expenses {
                        context.delete(expense)
                    }
                }
                
                // Add new expenses
                for expense in monthSetting.annualExpenses {
                    let expenseEntity = AnnualExpenseEntity(context: context)
                    expenseEntity.id = expense.id
                    expenseEntity.title = expense.title
                    expenseEntity.amount = expense.amount
                    expenseEntity.dueDate = expense.dueDate
                    expenseEntity.monthSetting = entity
                }
                
                try context.save()
            }
        } catch {
            print("Failed to update month setting: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Payday Methods
    
    func savePayday(_ payday: Payday) {
        let context = persistentContainer.viewContext
        let paydayEntity = PaydayEntity(context: context)
        paydayEntity.id = payday.id
        paydayEntity.date = payday.date
        
        do {
            try context.save()
        } catch {
            print("Failed to save payday: \(error.localizedDescription)")
        }
    }
    
    func fetchPaydays() -> [Payday] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { entity in
                Payday(
                    id: entity.id ?? UUID(),
                    date: entity.date ?? Date()
                )
            }
        } catch {
            print("Failed to fetch paydays: \(error.localizedDescription)")
            return []
        }
    }
    
    func deletePayday(id: UUID) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let paydayEntity = results.first {
                context.delete(paydayEntity)
                try context.save()
            }
        } catch {
            print("Failed to delete payday: \(error.localizedDescription)")
        }
    }
}

// DataManager.swift
import Foundation
import SwiftUI
import Combine

class DataManager: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var userCards: [Card] = []
    @Published var monthSettings: [MonthSetting] = []
    @Published var paydays: [Payday] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadAll()
    }
    
    func loadAll() {
        isLoading = true
        
        loadInvoices()
        loadCards()
        loadMonthSettings()
        loadPaydays()
        
        isLoading = false
    }
    
    // MARK: - Invoice Methods
    
    func loadInvoices() {
        invoices = CoreDataManager.shared.fetchInvoices()
        updateInvoiceStatuses()
    }
    
    func saveInvoice(_ invoice: Invoice) {
        CoreDataManager.shared.saveInvoice(invoice)
        loadInvoices()
        
        // Schedule notification
        scheduleReminderForInvoice(invoice)
    }
    
    func deleteInvoice(at offsets: IndexSet) {
        for index in offsets {
            let invoice = invoices[index]
            CoreDataManager.shared.deleteInvoice(id: invoice.id)
            
            // Cancel any scheduled notifications
            cancelNotificationForInvoice(invoice)
        }
        loadInvoices()
    }
    
    func updateInvoiceStatuses() {
        let today = Date()
        var updated = false
        
        for i in 0..<invoices.count {
            if invoices[i].dueDate < today && invoices[i].status == .pending {
                invoices[i].status = .overdue
                CoreDataManager.shared.updateInvoice(invoices[i])
                updated = true
            }
        }
        
        if updated {
            loadInvoices()
        }
    }
    
    // MARK: - Card Methods
    
    func loadCards() {
        userCards = CoreDataManager.shared.fetchCards()
    }
    
    func saveCard(_ card: Card) {
        CoreDataManager.shared.saveCard(card)
        loadCards()
    }
    
    func deleteCard(at offsets: IndexSet) {
        for index in offsets {
            let card = userCards[index]
            CoreDataManager.shared.deleteCard(id: card.id)
        }
        loadCards()
    }
    
    // MARK: - Month Settings Methods
    
    func loadMonthSettings() {
        monthSettings = CoreDataManager.shared.fetchMonthSettings()
    }
    
    func saveMonthSetting(_ setting: MonthSetting) {
        CoreDataManager.shared.saveMonthSetting(setting)
        loadMonthSettings()
    }
    
    // MARK: - Payday Methods
    
    func loadPaydays() {
        paydays = CoreDataManager.shared.fetchPaydays()
    }
    
    func savePayday(_ payday: Payday) {
        CoreDataManager.shared.savePayday(payday)
        loadPaydays()
    }
    
    func deletePayday(_ id: UUID) {
        CoreDataManager.shared.deletePayday(id: id)
        loadPaydays()
    }
    
    // MARK: - Notification Methods
    
    func scheduleReminderForInvoice(_ invoice: Invoice) {
        guard let reminderDate = invoice.reminderDate else { return }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        // Request authorization if not already granted
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if !granted || error != nil {
                print("Notification permission not granted or error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Invoice Payment Reminder"
            content.body = "\(invoice.title) is due soon. Amount: \(invoice.formattedAmount)"
            content.sound = .default
            
            // Create trigger based on reminder date
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: "invoice-\(invoice.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            // Add request to notification center
            notificationCenter.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelNotificationForInvoice(_ invoice: Invoice) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["invoice-\(invoice.id.uuidString)"])
    }
    
    // MARK: - Payment Prioritization
    
    func getPrioritizedInvoices() -> [Invoice] {
        // Sort pending invoices by due date, then by priority
        return invoices
            .filter { $0.status == .pending }
            .sorted { first, second in
                if first.dueDate == second.dueDate {
                    return first.priority > second.priority
                }
                return first.dueDate < second.dueDate
            }
    }
    
    func getOverdueInvoices() -> [Invoice] {
        return invoices.filter { $0.status == .overdue }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    func getPaidInvoices() -> [Invoice] {
        return invoices.filter { $0.status == .paid }
            .sorted { $0.paymentDate ?? Date() > $1.paymentDate ?? Date() }
    }
    
    func getUpcomingInvoices(limit: Int = 10) -> [Invoice] {
        return invoices
            .filter { $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0 }
    }
    
    func getTotalDueThisMonth() -> Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return invoices
            .filter { invoice in
                let month = calendar.component(.month, from: invoice.dueDate)
                let year = calendar.component(.year, from: invoice.dueDate)
                return month == currentMonth && year == currentYear && invoice.status != .paid
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getInvoicesForMonth(month: Int, year: Int) -> [Invoice] {
        let calendar = Calendar.current
        
        return invoices.filter { invoice in
            let invoiceMonth = calendar.component(.month, from: invoice.dueDate)
            let invoiceYear = calendar.component(.year, from: invoice.dueDate)
            return invoiceMonth == month && invoiceYear == year
        }
    }
    
    func isMonthCritical(month: Int, year: Int) -> Bool {
        return monthSettings.contains { setting in
            setting.month == month && setting.year == year && setting.isCritical
        }
    }
    
    func isMonthLowIncome(month: Int, year: Int) -> Bool {
        return monthSettings.contains { setting in
            setting.month == month && setting.year == year && setting.isLowIncome
        }
    }
    
    func markInvoiceAsPaid(_ invoice: Invoice) {
        var updatedInvoice = invoice
        updatedInvoice.status = .paid
        updatedInvoice.isPaid = true
        updatedInvoice.paymentDate = Date()
        
        CoreDataManager.shared.updateInvoice(updatedInvoice)
        loadInvoices()
    }
}