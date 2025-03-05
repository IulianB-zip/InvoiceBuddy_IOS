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
                .environmentObject(dependencies.settingsViewModel)
                .environmentObject(dependencies.scannerViewModel)
                .environmentObject(dependencies.paymentMethodsViewModel)
        }
    }
}

// AppDependencies.swift
import Foundation
import SwiftUI
import Combine

class AppDependencies {
    // Core data controller
    let persistenceController = PersistenceController.shared
    
    // Services
    lazy var invoiceService: InvoiceServiceProtocol = InvoiceService(persistenceController: persistenceController)
    lazy var cardService: CardServiceProtocol = CardService(persistenceController: persistenceController)
    lazy var monthSettingService: MonthSettingServiceProtocol = MonthSettingService(persistenceController: persistenceController)
    lazy var paydayService: PaydayServiceProtocol = PaydayService(persistenceController: persistenceController)
    lazy var notificationService: NotificationServiceProtocol = NotificationService()
    lazy var scanningService: ScanningServiceProtocol = ScanningService()
    lazy var prioritizationService: PrioritizationServiceProtocol = PrioritizationService(
        invoiceService: invoiceService,
        paydayService: paydayService,
        monthSettingService: monthSettingService
    )
    
    // ViewModels
    lazy var invoiceViewModel: InvoiceViewModel = {
        InvoiceViewModel(
            invoiceService: invoiceService,
            cardService: cardService,
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

// PersistenceController.swift
import Foundation
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "InvoiceManager")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error.localizedDescription)")
            }
        }
        
        // Automatically merge changes from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Merge policy to handle conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// Service Protocols

// InvoiceServiceProtocol.swift
import Foundation
import Combine

protocol InvoiceServiceProtocol {
    func fetchInvoices() -> AnyPublisher<[Invoice], Error>
    func saveInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error>
    func updateInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error>
    func deleteInvoice(id: UUID) -> AnyPublisher<Void, Error>
    func getInvoicesByMonth(year: Int, month: Int) -> AnyPublisher<[Invoice], Error>
    func getUpcomingInvoices(limit: Int) -> AnyPublisher<[Invoice], Error>
}

// InvoiceService.swift
import Foundation
import CoreData
import Combine

class InvoiceService: InvoiceServiceProtocol {
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

// InvoiceViewModel.swift
import Foundation
import Combine
import SwiftUI

class InvoiceViewModel: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let invoiceService: InvoiceServiceProtocol
    private let cardService: CardServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(invoiceService: InvoiceServiceProtocol,
         cardService: CardServiceProtocol,
         notificationService: NotificationServiceProtocol) {
        self.invoiceService = invoiceService
        self.cardService = cardService
        self.notificationService = notificationService
        
        loadInvoices()
    }
    
    func loadInvoices() {
        isLoading = true
        
        invoiceService.fetchInvoices()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] invoices in
                self?.invoices = invoices
                self?.updateOverdueInvoices()
            }
            .store(in: &cancellables)
    }
    
    func saveInvoice(_ invoice: Invoice) {
        isLoading = true
        
        invoiceService.saveInvoice(invoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadInvoices()
                }
            } receiveValue: { [weak self] _ in
                // Schedule notification if there's a reminder date
                if let reminderDate = invoice.reminderDate {
                    self?.scheduleReminderNotification(for: invoice)
                }
            }
            .store(in: &cancellables)
    }
    
    func deleteInvoice(at offsets: IndexSet) {
        for index in offsets {
            let invoice = invoices[index]
            
            invoiceService.deleteInvoice(id: invoice.id)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.loadInvoices()
                    }
                } receiveValue: { _ in }
                .store(in: &cancellables)
        }
    }
    
    func updateInvoiceStatus(_ invoice: Invoice, status: PaymentStatus) {
        var updatedInvoice = invoice
        updatedInvoice.status = status
        
        if status == .paid {
            updatedInvoice.isPaid = true
            updatedInvoice.paymentDate = Date()
        }
        
        invoiceService.updateInvoice(updatedInvoice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.loadInvoices()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    private func updateOverdueInvoices() {
        let today = Date()
        
        for (index, invoice) in invoices.enumerated() {
            if invoice.dueDate < today && invoice.status == .pending {
                var updatedInvoice = invoice
                updatedInvoice.status = .overdue
                
                invoiceService.updateInvoice(updatedInvoice)
                    .sink { _ in } receiveValue: { _ in }
                    .store(in: &cancellables)
                
                // Update local collection without reloading
                invoices[index].status = .overdue
            }
        }
    }
    
    private func scheduleReminderNotification(for invoice: Invoice) {
        guard let reminderDate = invoice.reminderDate else { return }
        
        notificationService.scheduleInvoiceReminder(invoice: invoice, reminderDate: reminderDate)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Failed to schedule reminder: \(error.localizedDescription)"
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    // Additional helper methods for filtering, sorting, etc.
    func upcomingInvoices(limit: Int = 5) -> [Invoice] {
        return invoices
            .filter { $0.dueDate >= Date() && $0.status == .pending }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(limit)
            .map { $0 }
    }
    
    func overdueInvoices() -> [Invoice] {
        return invoices
            .filter { $0.status == .overdue }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    func thisMonthTotal() -> Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        return invoices
            .filter { invoice in
                let month = calendar.component(.month, from: invoice.dueDate)
                let year = calendar.component(.year, from: invoice.dueDate)
                return month == currentMonth && year == currentYear
            }
            .reduce(0) { $0 + $1.amount }
    }
}

// NotificationServiceProtocol.swift
import Foundation
import Combine

protocol NotificationServiceProtocol {
    func requestPermissions() -> AnyPublisher<Bool, Error>
    func scheduleInvoiceReminder(invoice: Invoice, reminderDate: Date) -> AnyPublisher<Void, Error>
    func cancelInvoiceReminder(invoiceId: UUID) -> AnyPublisher<Void, Error>
}

// NotificationService.swift
import Foundation
import UserNotifications
import Combine

class NotificationService: NotificationServiceProtocol {
    func requestPermissions() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    promise(.failure(AppError.notificationError("Failed to request permissions: \(error.localizedDescription)")))
                } else {
                    promise(.success(granted))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func scheduleInvoiceReminder(invoice: Invoice, reminderDate: Date) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let content = UNMutableNotificationContent()
            content.title = "Invoice Payment Reminder"
            content.body = "\(invoice.title) is due soon. Amount: $\(String(format: "%.2f", invoice.amount))"
            content.sound = .default
            
            // Extract date components for the trigger
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            
            // Default to 9 AM if no specific time was set
            if dateComponents.hour == 0 && dateComponents.minute == 0 {
                dateComponents.hour = 9
                dateComponents.minute = 0
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create a unique identifier using the invoice ID
            let identifier = "invoice-reminder-\(invoice.id.uuidString)"
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    promise(.failure(AppError.notificationError("Failed to schedule notification: \(error.localizedDescription)")))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func cancelInvoiceReminder(invoiceId: UUID) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            let identifier = "invoice-reminder-\(invoiceId.uuidString)"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
}

// AppError.swift
import Foundation

enum AppError: Error, LocalizedError {
    case databaseError(String)
    case notificationError(String)
    case scanningError(String)
    case validationError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database Error: \(message)"
        case .notificationError(let message):
            return "Notification Error: \(message)"
        case .scanningError(let message):
            return "Scanning Error: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        }
    }
}
