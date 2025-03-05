//
//  PaydayRepository.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/Services/Implementations/PaydayRepository.swift
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
            
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
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