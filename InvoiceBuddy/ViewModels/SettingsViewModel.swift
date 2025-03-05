//
//  SettingsViewModel.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// Path: InvoiceBuddy/ViewModels/SettingsViewModel.swift
import Foundation
import Combine
import SwiftUI

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
        is