//
//  InvoiceRepository.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// Repository implementations for InvoiceBuddy

// InvoiceRepository.swift
import Foundation
import CoreData
import Combine

class InvoiceRepository: InvoiceService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    func fetchInvoices() -> AnyPublisher<[Invoice], Error> {
        return Future<[Invoice], Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
            
            do {
                let invoiceEntities = try context.fetch(fetchRequest)
                let invoices = invoiceEntities.map { self.mapToInvoice($0) }
                promise(.success(invoices))
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch invoices: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func saveInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            
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
                promise(.success(()))
            } catch {
                promise(.failure(AppError.databaseError("Failed to save invoice: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func updateInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
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
                    promise(.success(()))
                } else {
                    promise(.failure(AppError.databaseError("Invoice not found")))
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to update invoice: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteInvoice(id: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let invoiceEntity = results.first {
                    context.delete(invoiceEntity)
                    try context.save()
                    promise(.success(()))
                } else {
                    promise(.failure(AppError.databaseError("Invoice not found")))
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to delete invoice: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func getInvoicesByMonth(year: Int, month: Int) -> AnyPublisher<[Invoice], Error> {
        return Future<[Invoice], Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
            
            // Create date range for the month
            let calendar = Calendar.current
            var startDateComponents = DateComponents()
            startDateComponents.year = year
            startDateComponents.month = month
            startDateComponents.day = 1
            
            var endDateComponents = DateComponents()
            endDateComponents.year = year
            endDateComponents.month = month + 1
            endDateComponents.day = 1
            endDateComponents.second = -1
            
            guard let startDate = calendar.date(from: startDateComponents),
                  let endDate = calendar.date(from: endDateComponents) else {
                promise(.failure(AppError.validationError("Invalid date components")))
                return
            }
            
            fetchRequest.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate <= %@",
                                               startDate as NSDate,
                                               endDate as NSDate)
            
            do {
                let invoiceEntities = try context.fetch(fetchRequest)
                let invoices = invoiceEntities.map { self.mapToInvoice($0) }
                promise(.success(invoices))
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch invoices by month: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func getUpcomingInvoices(limit: Int) -> AnyPublisher<[Invoice], Error> {
        return Future<[Invoice], Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<InvoiceEntity> = InvoiceEntity.fetchRequest()
            
            // Get invoices with due dates in the future and pending status
            fetchRequest.predicate = NSPredicate(format: "dueDate >= %@ AND status == %@",
                                               Date() as NSDate,
                                               PaymentStatus.pending.rawValue)
            
            // Sort by due date (earliest first)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
            
            // Limit results
            fetchRequest.fetchLimit = limit
            
            do {
                let invoiceEntities = try context.fetch(fetchRequest)
                let invoices = invoiceEntities.map { self.mapToInvoice($0) }
                promise(.success(invoices))
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch upcoming invoices: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    // Helper method to map from Core Data entity to model
    private func mapToInvoice(_ entity: InvoiceEntity) -> Invoice {
        return Invoice(
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
}

// CardRepository.swift
import Foundation
import CoreData
import Combine

class CardRepository: CardService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    func fetchCards() -> AnyPublisher<[Card], Error> {
        return Future<[Card], Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
            
            do {
                let cardEntities = try context.fetch(fetchRequest)
                let cards = cardEntities.map { self.mapToCard($0) }
                promise(.success(cards))
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch cards: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func saveCard(_ card: Card) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            
            // If this is the default card, unset default on other cards
            if card.isDefault {
                self.unsetDefaultCards(context: context)
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
                promise(.success(()))
            } catch {
                promise(.failure(AppError.databaseError("Failed to save card: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func updateCard(_ card: Card) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", card.id as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let cardEntity = results.first {
                    // If setting this card as default, unset others
                    if !cardEntity.isDefault && card.isDefault {
                        self.unsetDefaultCards(context: context)
                    }
                    
                    cardEntity.name = card.name
                    cardEntity.type = card.type.rawValue
                    cardEntity.lastFourDigits = card.lastFourDigits
                    cardEntity.expiryDate = card.expiryDate
                    cardEntity.isDefault = card.isDefault
                    
                    try context.save()
                    promise(.success(()))
                } else {
                    promise(.failure(AppError.databaseError("Card not found")))
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to update card: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteCard(id: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let cardEntity = results.first {
                    context.delete(cardEntity)
                    try context.save()
                    promise(.success(()))
                } else {
                    promise(.failure(AppError.databaseError("Card not found")))
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to delete card: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func getDefaultCard() -> AnyPublisher<Card?, Error> {
        return Future<Card?, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isDefault == %@", NSNumber(value: true))
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if let cardEntity = results.first {
                    promise(.success(self.mapToCard(cardEntity)))
                } else {
                    promise(.success(nil)) // No default card found, but not an error
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch default card: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    // Helper method to map from Core Data entity to model
    private func mapToCard(_ entity: CardEntity) -> Card {
        return Card(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            type: CardType(rawValue: entity.type ?? "") ?? .credit,
            lastFourDigits: entity.lastFourDigits ?? "",
            expiryDate: entity.expiryDate ?? Date(),
            isDefault: entity.isDefault
        )
    }
    
    private func unsetDefaultCards(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<CardEntity> = CardEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isDefault == %@", NSNumber(value: true))
        
        do {
            let results = try context.fetch(fetchRequest)
            for cardEntity in results {
                cardEntity.isDefault = false
            }
        } catch {
            print("Failed to unset default cards: \(error.localizedDescription)")
        }
    }
}

// MonthSettingRepository.swift
import Foundation
import CoreData
import Combine

class MonthSettingRepository: MonthSettingService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    func fetchMonthSettings() -> AnyPublisher<[MonthSetting], Error> {
        return Future<[MonthSetting], Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
            
            do {
                let entities = try context.fetch(fetchRequest)
                let settings = entities.map { self.mapToMonthSetting($0) }
                promise(.success(settings))
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch month settings: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func fetchMonthSetting(year: Int, month: Int) -> AnyPublisher<MonthSetting?, Error> {
        return Future<MonthSetting?, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "year == %d AND month == %d", year, month)
            fetchRequest.fetchLimit = 1
            
            do {
                let entities = try context.fetch(fetchRequest)
                if let entity = entities.first {
                    promise(.success(self.mapToMonthSetting(entity)))
                } else {
                    promise(.success(nil)) // No setting found for this month, but not an error
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch month setting: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func saveMonthSetting(_ setting: MonthSetting) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            
            // Check if setting for this month already exists
            let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "year == %d AND month == %d", setting.year, setting.month)
            
            do {
                let existingSettings = try context.fetch(fetchRequest)
                
                if let existingEntity = existingSettings.first {
                    // Update existing setting
                    self.updateMonthSettingEntity(existingEntity, with: setting, in: context)
                } else {
                    // Create new setting
                    self.createMonthSettingEntity(from: setting, in: context)
                }
                
                try context.save()
                promise(.success(()))
            } catch {
                promise(.failure(AppError.databaseError("Failed to save month setting: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func deleteMonthSetting(id: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<MonthSettingEntity> = MonthSettingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let settingEntity = results.first {
                    context.delete(settingEntity)
                    try context.save()
                    promise(.success(()))
                } else {
                    promise(.failure(AppError.databaseError("Month setting not found")))
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to delete month setting: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    // Helper method to map from Core Data entity to model
    private func mapToMonthSetting(_ entity: MonthSettingEntity) -> MonthSetting {
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
    
    private func createMonthSettingEntity(from setting: MonthSetting, in context: NSManagedObjectContext) {
        let settingEntity = MonthSettingEntity(context: context)
        settingEntity.id = setting.id
        settingEntity.year = Int16(setting.year)
        settingEntity.month = Int16(setting.month)
        settingEntity.isCritical = setting.isCritical
        settingEntity.isLowIncome = setting.isLowIncome
        settingEntity.note = setting.note
        
        // Create annual expenses
        for expense in setting.annualExpenses {
            let expenseEntity = AnnualExpenseEntity(context: context)
            expenseEntity.id = expense.id
            expenseEntity.title = expense.title
            expenseEntity.amount = expense.amount
            expenseEntity.dueDate = expense.dueDate
            expenseEntity.monthSetting = settingEntity
        }
    }
    
    private func updateMonthSettingEntity(_ entity: MonthSettingEntity, with setting: MonthSetting, in context: NSManagedObjectContext) {
        entity.id = setting.id
        entity.year = Int16(setting.year)
        entity.month = Int16(setting.month)
        entity.isCritical = setting.isCritical
        entity.isLowIncome = setting.isLowIncome
        entity.note = setting.note
        
        // Delete existing expenses
        if let expenses = entity.annualExpenses {
            for case let expense as AnnualExpenseEntity in expenses {
                context.delete(expense)
            }
        }
        
        // Add new expenses
        for expense in setting.annualExpenses {
            let expenseEntity = AnnualExpenseEntity(context: context)
            expenseEntity.id = expense.id
            expenseEntity.title = expense.title
            expenseEntity.amount = expense.amount
            expenseEntity.dueDate = expense.dueDate
            expenseEntity.monthSetting = entity
        }
    }
}

// PaydayRepository.swift
import Foundation
import CoreData
import Combine

class PaydayRepository: PaydayService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    func fetchPaydays() -> AnyPublisher<[Date], Error> {
        return Future<[Date], Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
            
            // Sort by date
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            
            do {
                let entities = try context.fetch(fetchRequest)
                let paydays = entities.compactMap { $0.date }
                promise(.success(paydays))
            } catch {
                promise(.failure(AppError.databaseError("Failed to fetch paydays: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func savePayday(_ date: Date) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
            
            // Check if there's already a payday on the same date
            if self.paydayExists(date: date, context: context) {
                promise(.failure(AppError.validationError("A payday already exists on this date")))
                return
            }
            
            let paydayEntity = PaydayEntity(context: context)
            paydayEntity.id = UUID()
            paydayEntity.date = date
            
            do {
                try context.save()
                promise(.success(()))
            } catch {
                promise(.failure(AppError.databaseError("Failed to save payday: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func deletePayday(date: Date) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let context = self.persistenceController.viewContext
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
                promise(.success(()))
            } catch {
                promise(.failure(AppError.databaseError("Failed to delete payday: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    func getNextPayday(after date: Date) -> AnyPublisher<Date?, Error> {
        return Future<Date?, Error> { promise in
            let context = self.persistenceController.viewContext
            let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
            
            fetchRequest.predicate = NSPredicate(format: "date > %@", date as NSDate)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if let entity = results.first, let paydayDate = entity.date {
                    promise(.success(paydayDate))
                } else {
                    promise(.success(nil)) // No upcoming payday found
                }
            } catch {
                promise(.failure(AppError.databaseError("Failed to get next payday: \(error.localizedDescription)")))
            }
        }.eraseToAnyPublisher()
    }
    
    private func paydayExists(date: Date, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<PaydayEntity> = PaydayEntity.fetchRequest()
        
        // Create a predicate that matches dates on the same day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.predicate = predicate
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking for existing payday: \(error.localizedDescription)")
            return false
        }
    }
}