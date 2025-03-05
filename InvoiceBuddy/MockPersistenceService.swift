//
//  MockPersistenceService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// Mocks/MockPersistenceService.swift
import Foundation

class MockPersistenceService: PersistenceService {
    var invoices: [Invoice] = []
    var cards: [Card] = []
    var monthSettings: [MonthSetting] = []
    var paydays: [Date] = []
    
    // Mock implementations of all required methods
    func fetchInvoices() -> [Invoice] {
        return invoices
    }
    
    func saveInvoice(_ invoice: Invoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        } else {
            invoices.append(invoice)
        }
    }
    
    // ... other methods
}

// Tests/DataManagerTests.swift
import XCTest
@testable import InvoiceBuddy

class DataManagerTests: XCTestCase {
    var mockPersistenceService: MockPersistenceService!
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        mockPersistenceService = MockPersistenceService()
        dataManager = DataManager(persistenceService: mockPersistenceService)
    }
    
    func testLoadInvoices() {
        // Given
        let testInvoice = Invoice(title: "Test", description: "Test Invoice", amount: 100.0, dueDate: Date())
        mockPersistenceService.invoices = [testInvoice]
        
        // When
        dataManager.loadInvoices()
        
        // Then
        XCTAssertEqual(dataManager.invoices.count, 1)
        XCTAssertEqual(dataManager.invoices.first?.title, "Test")
    }
    
    // Additional tests...
}
