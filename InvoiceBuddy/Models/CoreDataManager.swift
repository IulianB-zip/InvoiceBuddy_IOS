// InvoiceManager.xcdatamodeld
/*
This would be created using Xcode's Core Data model editor, but here's a representation
of what the entities would look like:

Entity: InvoiceEntity
- id: UUID
- title: String
- description: String
- amount: Double
- dueDate: Date
- status: String (enum stored as string)
- paymentMethod: String (enum stored as string)
- reminderDate: Date (optional)
- barcode: String (optional)
- qrData: String (optional)
- notes: String (optional)
- priority: Int16
- isPaid: Bool
- paymentDate: Date (optional)
- associatedCardId: String (optional)

Entity: CardEntity
- id: UUID
- name: String
- type: String (enum stored as string)
- lastFourDigits: String
- expiryDate: Date
- isDefault: Bool

Entity: MonthSettingEntity
- id: UUID
- year: Int16
- month: Int16
- isCritical: Bool
- isLowIncome: Bool
- note: String (optional)
- relationship to AnnualExpenseEntity (one-to-many)

Entity: AnnualExpenseEntity
- id: UUID
- title: String
- amount: Double
- dueDate: Date
- relationship to MonthSettingEntity (many-to-one)

Entity: PaydayEntity
- id: UUID
- date: Date
*/

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
    
    func savePayday(_ date: Date) {
        let context = persistentContainer.viewContext
        let paydayEntity = PaydayEntity(context: context)
        paydayEntity.id = UUID()
        paydayEntity.date = date
        
        do {
            try context.save()
        } catch {
            print("Failed to save payday: \(error.localizedDescription)")
        }
    }
    
    func fetchPaydays() -> [Date] {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.date }
        } catch {
            print("Failed to fetch paydays: \(error.localizedDescription)")
            return []
        }
    }
    
    func deletePayday(date: Date) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
        
        // Create a predicate that matches dates on the same day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.predicate = predicate
        
        do {
            let results = try context.fetch(fetchRequest)
            for entity in results {
                context.delete(entity)
            }
            try context.save()
        } catch {
            print("Failed to delete payday: \(error.localizedDescription)")
        }
    }
}

// Implement DataManager methods to use CoreDataManager
extension DataManager {
    func loadInvoices() {
        invoices = CoreDataManager.shared.fetchInvoices()
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
        }
        loadInvoices()
    }
    
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
    
    func loadMonthSettings() {
        monthSettings = CoreDataManager.shared.fetchMonthSettings()
    }
    
    func saveMonthSetting(_ setting: MonthSetting) {
        CoreDataManager.shared.saveMonthSetting(setting)
        loadMonthSettings()
    }
    
    func loadPaydays() -> [Date] {
        return CoreDataManager.shared.fetchPaydays()
    }
    
    func savePayday(_ date: Date) {
        CoreDataManager.shared.savePayday(date)
    }
    
    func deletePayday(_ date: Date) {
        CoreDataManager.shared.deletePayday(date: date)
    }
}
