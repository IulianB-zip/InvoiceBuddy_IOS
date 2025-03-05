//
//  PaydayService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// PaydayService.swift
import Foundation
import Combine

protocol PaydayService {
    func fetchPaydays() -> AnyPublisher<[Date], Error>
    func savePayday(_ date: Date) -> AnyPublisher<Void, Error>
    func deletePayday(date: Date) -> AnyPublisher<Void, Error>
    func getNextPayday(after date: Date) -> AnyPublisher<Date?, Error>
}
