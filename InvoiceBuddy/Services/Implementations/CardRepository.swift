//
//  CardRepository.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/Services/Implementations/CardRepository.swift
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
            
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
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
            let context = self.persistenceController.container.viewContext
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