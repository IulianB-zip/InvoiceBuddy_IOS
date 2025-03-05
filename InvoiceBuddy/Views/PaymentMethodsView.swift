//
//  PaymentMethodsView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Payment Methods Views

import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject var invoiceViewModel: InvoiceViewModel
    @State private var showingAddCard = false
    @State private var cards: [Card] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let cardService: CardService
    
    init(cardService: CardService = CardRepository(persistenceController: PersistenceController.shared)) {
        self.cardService = cardService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    Section(header: Text("My Cards")) {
                        ForEach(cards) { card in
                            CardRow(card: card)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        deleteCard(card)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    if !card.isDefault {
                                        Button {
                                            setDefaultCard(card)
                                        } label: {
                                            Label("Set Default", systemImage: "star")
                                        }
                                        .tint(.yellow)
                                    }
                                }
                        }
                        
                        Button(action: {
                            showingAddCard = true
                        }) {
                            Label("Add New Card", systemImage: "plus")
                        }
                    }
                    
                    Section(header: Text("Payment Methods")) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            HStack {
                                Image(systemName: iconForPaymentMethod(method))
                                    .foregroundColor(colorForPaymentMethod(method))
                                Text(method.rawValue)
                            }
                        }
                    }
                }
                .refreshable {
                    loadCards()
                }
                .overlay {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else if cards.isEmpty {
                        ContentUnavailableView(
                            label: {
                                Label("No Payment Cards", systemImage: "creditcard")
                            },
                            description: {
                                Text("Add your first card to simplify payments")
                            },
                            actions: {
                                Button(action: { showingAddCard = true }) {
                                    Text("Add Card")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                    }
                }
                .navigationTitle("Payment Methods")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddCard = true }) {
                            Label("Add Card", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddCard) {
                    AddCardView(cardService: cardService, onSave: {
                        loadCards()
                    })
                }
                .onAppear {
                    loadCards()
                }
                
                if let errorMessage = errorMessage {
                    ErrorBanner(message: errorMessage)
                }
            }
        }
    }
    
    private func loadCards() {
        isLoading = true
        errorMessage = nil
        
        cardService.fetchCards()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { fetchedCards in
                self.cards = fetchedCards.sorted { $0.isDefault && !$1.isDefault }
            }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func deleteCard(_ card: Card) {
        isLoading = true
        errorMessage = nil
        
        cardService.deleteCard(id: card.id)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    loadCards()
                }
            } receiveValue: { _ in }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func setDefaultCard(_ card: Card) {
        isLoading = true
        errorMessage = nil
        
        var updatedCard = card
        updatedCard.isDefault = true
        
        cardService.updateCard(updatedCard)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                isLoading = false
                
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                } else {
                    loadCards()
                }
            } receiveValue: { _ in }
            .store(in: &Set<AnyCancellable>())
    }
    
    private func iconForPaymentMethod(_ method: PaymentMethod) -> String {
        switch method {
        case .creditCard:
            return "creditcard"
        case .debitCard:
            return "creditcard.fill"
        case .bankTransfer:
            return "building.columns"
        case .cash:
            return "banknote"
        case .other:
            return "ellipsis.circle"
        }
    }
    
    private func colorForPaymentMethod(_ method: PaymentMethod) -> Color {
        switch method {
        case .creditCard:
            return .blue
        case .debitCard:
            return .green
        case .bankTransfer:
            return .purple
        case .cash:
            return .orange
        case .other:
            return .gray
        }
    }
}

struct CardRow: View {
    var card: Card
    
    var body: some View {
        HStack {
            Image(systemName: card.type == .credit ? "creditcard" : "creditcard.fill")
                .foregroundColor(card.type == .credit ? .blue : .green)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                Text("**** **** **** \(card.lastFourDigits)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(card.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(expiryDateFormatted(card.expiryDate))
                    .font(.caption)
                    .foregroundColor(isExpired(card.expiryDate) ? .red : .secondary)
            }
            
            if card.isDefault {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func expiryDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: date)
    }
    
    private func isExpired(_ date: Date) -> Bool {
        return date < Date()
    }
}

struct AddCardView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var cardName = ""
    @State private var cardType: CardType = .credit
    @State private var lastFourDigits = ""
    @State private var expiryDate = Date()
    @State private var isDefault = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let cardService: CardService
    private let onSave: () -> Void
    
    init(cardService: CardService, onSave: @escaping () -> Void) {
        self.cardService = cardService
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Card Details")) {
                        TextField("Card Name", text: $cardName)
                            .autocapitalization(.words)
                        
                        Picker("Card Type", selection: $cardType) {
                            ForEach(CardType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        
                        TextField("Last 4 Digits", text: $lastFourDigits)
                            .keyboardType(.numberPad)
                            .onChange(of: lastFourDigits) { newValue in
                                if newValue.count > 4 {
                                    lastFourDigits = String(newValue.prefix(4))
                                }
                                // Keep only digits
                                lastFourDigits = newValue.filter { "0123456789".contains($0) }
                            }
                        
                        DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: [.date])
                        
                        Toggle("Set as Default", isOn: $isDefault)
                    }
                    
                    Section {
                        CardPreview(
                            name: cardName.isEmpty ? "Card Name" : cardName,
                            type: cardType,
                            lastFourDigits: lastFourDigits.isEmpty ? "••••" : lastFourDigits,
                            expiryDate: expiryDate
                        )
                    }
                }
                .navigationTitle("Add Card")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveCard()
                        }
                        .disabled(cardName.isEmpty || lastFourDigits.count < 4 || isLoading)
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
    
    private func saveCard() {
        isLoading = true
        errorMessage = nil
        
        let card = Card(
            name: cardName,
            type: cardType,
            lastFourDigits: lastFourDigits,
            expiryDate: expiryDate,
            isDefault: isDefault
        )
        
        cardService.saveCard(card)
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
}

struct CardPreview: View {
    var name: String
    var type: CardType
    var lastFourDigits: String
    var expiryDate: Date
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(type == .credit ? Color.blue.opacity(0.8) : Color.green.opacity(0.8))
                .frame(height: 200)
            
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "creditcard")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("**** **** **** \(lastFourDigits)")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("CARD HOLDER")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("EXPIRES")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(expiryDateFormatted(expiryDate))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
    }
    
    private func expiryDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yy"
        return formatter.string(from: date)
    }
}