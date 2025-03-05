//
//  PaymentMethodsViewModel.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/ViewModels/PaymentMethodsViewModel.swift
import Foundation
import Combine
import SwiftUI

class PaymentMethodsViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let cardService: CardService
    private var cancellables = Set<AnyCancellable>()
    
    init(cardService: CardService) {
        self.cardService = cardService
        loadCards()
    }
    
    func loadCards() {
        isLoading = true
        errorMessage = nil
        
        cardService.fetchCards()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] cards in
                self?.cards = cards.sorted { $0.isDefault && !$1.isDefault }
            }
            .store(in: &cancellables)
    }
    
    func saveCard(_ card: Card) {
        isLoading = true
        errorMessage = nil
        
        cardService.saveCard(card)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadCards()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func updateCard(_ card: Card) {
        isLoading = true
        errorMessage = nil
        
        cardService.updateCard(card)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadCards()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func deleteCard(id: UUID) {
        isLoading = true
        errorMessage = nil
        
        cardService.deleteCard(id: id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadCards()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func setDefaultCard(_ card: Card) {
        var updatedCard = card
        updatedCard.isDefault = true
        updateCard(updatedCard)
    }
    
    func getCardById(_ id: UUID) -> Card? {
        return cards.first { $0.id == id }
    }
    
    func getDefaultCard() -> Card? {
        return cards.first { $0.isDefault }
    }
    
    func createNewCard(name: String, type: CardType, lastFourDigits: String, expiryDate: Date, isDefault: Bool) -> Card {
        return Card(
            name: name,
            type: type,
            lastFourDigits: lastFourDigits,
            expiryDate: expiryDate,
            isDefault: isDefault
        )
    }
    
    func isCardExpired(_ card: Card) -> Bool {
        // Check if card is expired (compares only year and month)
        let calendar = Calendar.current
        let currentDate = Date()
        
        let cardYear = calendar.component(.year, from: card.expiryDate)
        let cardMonth = calendar.component(.month, from: card.expiryDate)
        
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        return (cardYear < currentYear) || (cardYear == currentYear && cardMonth < currentMonth)
    }
    
    func formatExpiryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: date)
    }
}