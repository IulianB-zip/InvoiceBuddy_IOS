//
//  MonthSettingRepository.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/Services/Implementations/MonthSettingRepository.swift
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
            
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
            let context = self.persistenceController.container.viewContext
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