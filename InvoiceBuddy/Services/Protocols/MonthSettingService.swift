//
//  MonthSettingService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// MonthSettingService.swift
import Foundation
import Combine

protocol MonthSettingService {
    func fetchMonthSettings() -> AnyPublisher<[MonthSetting], Error>
    func fetchMonthSetting(year: Int, month: Int) -> AnyPublisher<MonthSetting?, Error>
    func saveMonthSetting(_ setting: MonthSetting) -> AnyPublisher<Void, Error>
    func deleteMonthSetting(id: UUID) -> AnyPublisher<Void, Error>
}
