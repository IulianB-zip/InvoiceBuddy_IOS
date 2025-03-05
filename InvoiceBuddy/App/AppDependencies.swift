//
//  AppDependencies.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// AppDependencies.swift
import Foundation
import SwiftUI
import Combine

class AppDependencies {
    // Core data controller
    let persistenceController = PersistenceController.shared
    
    // Services
    lazy var invoiceService: InvoiceService = InvoiceRepository(persistenceController: persistenceController)
    lazy var cardService: CardService = CardRepository(persistenceController: persistenceController)
    lazy var monthSettingService: MonthSettingService = MonthSettingRepository(persistenceController: persistenceController)
    lazy var paydayService: PaydayService = PaydayRepository(persistenceController: persistenceController)
    lazy var notificationService: NotificationService = UNNotificationService()
    lazy var scanningService: ScanningServiceProtocol = QRScanningService()
    lazy var prioritizationService: PrioritizationService = PrioritizationServiceImpl(
        invoiceService: invoiceService,
        paydayService: paydayService,
        monthSettingService: monthSettingService
    )
    
    // ViewModels
    lazy var invoiceViewModel: InvoiceViewModel = {
        InvoiceViewModel(
            invoiceService: invoiceService,
            notificationService: notificationService
        )
    }()
    
    lazy var dashboardViewModel: DashboardViewModel = {
        DashboardViewModel(
            invoiceService: invoiceService,
            cardService: cardService
        )
    }()
    
    lazy var scannerViewModel: ScannerViewModel = {
        ScannerViewModel(
            scanningService: scanningService,
            invoiceService: invoiceService
        )
    }()
    
    lazy var paymentMethodsViewModel: PaymentMethodsViewModel = {
        PaymentMethodsViewModel(
            cardService: cardService
        )
    }()
    
    lazy var settingsViewModel: SettingsViewModel = {
        SettingsViewModel(
            monthSettingService: monthSettingService,
            paydayService: paydayService,
            notificationService: notificationService
        )
    }()
}

class DashboardViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var cards: [Card] = []
    @Published var monthlyTotals: [(month: Date, amount: Double)] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let invoiceService: InvoiceService
    private let cardService: CardService
    private var cancellables = Set<AnyCancellable>()
    
    init(invoiceService: InvoiceService, cardService: CardService) {
        self.invoiceService = invoiceService
        self.cardService = cardService
        
        loadData()
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Publishers.Zip(
            invoiceService.fetchInvoices(),
            cardService.fetchCards()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] (invoices, cards) in
            self?.invoices = invoices
            self?.cards = cards
            self?.calculateMonthlyTotals()
        }
        .store(in: &cancellables)
    }
    
    private func calculateMonthlyTotals() {
        let calendar = Calendar.current
        var monthlyData: [Date: Double] = [:]
        
        // Start with current month and go back 6 months
        let currentDate = Date()
        
        for monthOffset in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -monthOffset, to: currentDate) {
                let components = calendar.dateComponents([.year, .month], from: date)
                if let monthStartDate = calendar.date(from: components) {
                    monthlyData[monthStartDate] = 0
                }
            }
        }
        
        // Calculate total for each month
        for invoice in invoices {
            let invoiceComponents = calendar.dateComponents([.year, .month], from: invoice.dueDate)
            if let monthStartDate = calendar.date(from: invoiceComponents) {
                if monthlyData.keys.contains(monthStartDate) {
                    monthlyData[monthStartDate, default: 0] += invoice.amount
                }
            }
        }
        
        // Convert to array and sort by date
        monthlyTotals = monthlyData.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    func getUpcomingInvoices(limit: Int = 5) -> [Invoice] {
        return invoices
            .filter { $0.dueDate >= Date() && $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0 }
    }
    
    func getOverdueInvoices() -> [Invoice] {
        return invoices
            .filter { $0.status == .overdue }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    func getTotalDueAmount() -> Double {
        return invoices
            .filter { $0.status != .paid }
            .reduce(0) { $0 + $1.amount }
    }
    
    func getPaymentMethodDistribution() -> [PaymentMethod: Double] {
        let totalInvoices = Double(invoices.count)
        guard totalInvoices > 0 else { return [:] }
        
        var methodCounts: [PaymentMethod: Int] = [:]
        
        for invoice in invoices {
            if let method = invoice.paymentMethod {
                methodCounts[method, default: 0] += 1
            }
        }
        
        var percentages: [PaymentMethod: Double] = [:]
        for (method, count) in methodCounts {
            percentages[method] = Double(count) / totalInvoices * 100
        }
        
        return percentages
    }
}

class ScannerViewModel: ObservableObject {
    @Published var scannedData: ScannedInvoiceData?
    @Published var isScanning = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let scanningService: ScanningServiceProtocol
    private let invoiceService: InvoiceService
    private var cancellables = Set<AnyCancellable>()
    
    init(scanningService: ScanningServiceProtocol, invoiceService: InvoiceService) {
        self.scanningService = scanningService
        self.invoiceService = invoiceService
    }
    
    func scanImage(_ image: UIImage) {
        isLoading = true
        errorMessage = nil
        
        scanningService.comprehensiveScan(image)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] data in
                self?.scannedData = data
            }
            .store(in: &cancellables)
    }
    
    func saveScannedInvoice(title: String, description: String, amount: Double, dueDate: Date) {
        isLoading = true
        errorMessage = nil
        
        let invoice = Invoice(
            title: title,
            description: description,
            amount: amount,
            dueDate: dueDate,
            status: .pending,
            barcode: scannedData?.barcode,
            qrData: scannedData?.qrData
        )
        
        invoiceService.saveInvoice(invoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.scannedData = nil
                    self?.isScanning = false
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}

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
}

class SettingsViewModel: ObservableObject {
    @Published var monthSettings: [MonthSetting] = []
    @Published var paydays: [Date] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var notificationsEnabled = true
    @Published var weekendAwareReminders = true
    
    private let monthSettingService: MonthSettingService
    private let paydayService: PaydayService
    private let notificationService: NotificationService
    private var cancellables = Set<AnyCancellable>()
    
    init(monthSettingService: MonthSettingService, paydayService: PaydayService, notificationService: NotificationService) {
        self.monthSettingService = monthSettingService
        self.paydayService = paydayService
        self.notificationService = notificationService
        
        loadSettings()
        
        // Load user preferences
        self.weekendAwareReminders = UserDefaults.standard.bool(forKey: "weekendAwareReminders")
    }
    
    func loadSettings() {
        isLoading = true
        errorMessage = nil
        
        Publishers.Zip(
            monthSettingService.fetchMonthSettings(),
            paydayService.fetchPaydays()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            
            if case .failure(let error) = completion {
                self?.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] (settings, paydays) in
            self?.monthSettings = settings
            self?.paydays = paydays.sorted()
        }
        .store(in: &cancellables)
    }
    
    func saveMonthSetting(_ setting: MonthSetting) {
        isLoading = true
        errorMessage = nil
        
        monthSettingService.saveMonthSetting(setting)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadSettings()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func deleteMonthSetting(id: UUID) {
        isLoading = true
        errorMessage = nil
        
        monthSettingService.deleteMonthSetting(id: id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadSettings()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func savePayday(_ date: Date) {
        isLoading = true
        errorMessage = nil
        
        paydayService.savePayday(date)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadSettings()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func deletePayday(date: Date) {
        isLoading = true
        errorMessage = nil
        
        paydayService.deletePayday(date: date)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadSettings()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func requestNotificationPermissions() -> AnyPublisher<Bool, Error> {
        return notificationService.requestPermissions()
    }
    
    func toggleWeekendAwareReminders(_ enabled: Bool) {
        weekendAwareReminders = enabled
        UserDefaults.standard.set(enabled, forKey: "weekendAwareReminders")
    }
}

// InvoiceBuddyApp.swift
import SwiftUI

@main
struct InvoiceBuddyApp: App {
    let dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies.invoiceViewModel)
                .environmentObject(dependencies.dashboardViewModel)
                .environmentObject(dependencies.scannerViewModel)
                .environmentObject(dependencies.paymentMethodsViewModel)
                .environmentObject(dependencies.settingsViewModel)
        }
    }
}