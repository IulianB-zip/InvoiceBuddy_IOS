//
//  InvoiceService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// InvoiceService.swift
import Foundation
import Combine

protocol InvoiceService {
    func fetchInvoices() -> AnyPublisher<[Invoice], Error>
    func saveInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error>
    func updateInvoice(_ invoice: Invoice) -> AnyPublisher<Void, Error>
    func deleteInvoice(id: UUID) -> AnyPublisher<Void, Error>
    func getInvoicesByMonth(year: Int, month: Int) -> AnyPublisher<[Invoice], Error>
    func getUpcomingInvoices(limit: Int) -> AnyPublisher<[Invoice], Error>
}
