//
//  CardService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// CardService.swift
import Foundation
import Combine

protocol CardService {
    func fetchCards() -> AnyPublisher<[Card], Error>
    func saveCard(_ card: Card) -> AnyPublisher<Void, Error>
    func updateCard(_ card: Card) -> AnyPublisher<Void, Error>
    func deleteCard(id: UUID) -> AnyPublisher<Void, Error>
    func getDefaultCard() -> AnyPublisher<Card?, Error>
}
