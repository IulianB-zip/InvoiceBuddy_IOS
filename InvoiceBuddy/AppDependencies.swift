//
//  AppDependencies.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// AppDependencies.swift
import Foundation
import SwiftUI

class AppDependencies {
    // Persistence
    lazy var persistenceController = PersistenceController.shared
    
    // Services
    lazy var invoiceService: InvoiceService = InvoiceRepository(persistenceController: persistenceController)
    lazy var cardService: CardService = CardRepository(persistenceController: persistenceController)
    lazy var notificationService: NotificationService = UNNotificationService()
    lazy var scanningService: ScanningService = QRScanningService()
    
    // ViewModels
    lazy var invoiceViewModel = InvoiceViewModel(
        invoiceService: invoiceService,
        notificationService: notificationService
    )
    
    lazy var dashboardViewModel = DashboardViewModel(
        invoiceService: invoiceService,
        cardService: cardService
    )
    
    // Additional dependencies...
}

// Usage in app entry point
@main
struct InvoiceBuddyApp: App {
    let dependencies = AppDependencies()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies.invoiceViewModel)
                .environmentObject(dependencies.dashboardViewModel)
                // Additional view models...
        }
    }
}