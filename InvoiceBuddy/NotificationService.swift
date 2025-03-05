//
//  NotificationService.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// NotificationService.swift
import Foundation
import UserNotifications
import Combine

protocol NotificationService {
    func scheduleReminderForInvoice(_ invoice: Invoice)
    func cancelReminderForInvoice(id: UUID)
    func requestPermissions() -> AnyPublisher<Bool, Error>
}

class UNNotificationService: NotificationService {
    
    func scheduleReminderForInvoice(_ invoice: Invoice) {
        guard let reminderDate = invoice.reminderDate else { return }
        
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
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelReminderForInvoice(id: UUID) {
        let identifier = "invoice-reminder-\(id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
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
    
    func scheduleWeekendAwareReminder(for invoice: Invoice) {
        guard let reminderDate = invoice.reminderDate else { return }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: reminderDate)
        
        // If reminder falls on weekend, adjust it to Friday
        var adjustedDate = reminderDate
        if weekday == 1 { // Sunday
            adjustedDate = calendar.date(byAdding: .day, value: -2, to: reminderDate) ?? reminderDate
        } else if weekday == 7 { // Saturday
            adjustedDate = calendar.date(byAdding: .day, value: -1, to: reminderDate) ?? reminderDate
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Invoice Payment Reminder"
        content.body = "\(invoice.title) is due soon. Amount: $\(String(format: "%.2f", invoice.amount))"
        
        if adjustedDate != reminderDate {
            content.body += " (Reminder adjusted for weekend)"
        }
        
        content.sound = .default
        
        // Extract date components for the trigger
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: adjustedDate)
        
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
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func schedulePaymentConfirmation(for invoice: Invoice) {
        let content = UNMutableNotificationContent()
        content.title = "Payment Confirmation"
        content.body = "You marked \(invoice.title) as paid. Amount: $\(String(format: "%.2f", invoice.amount))"
        content.sound = .default
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create a unique identifier
        let identifier = "payment-confirmation-\(invoice.id.uuidString)"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling payment confirmation: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDueDateApproaching(for invoice: Invoice, daysUntilDue: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Invoice Due Soon"
        content.body = "\(invoice.title) is due in \(daysUntilDue) days. Amount: $\(String(format: "%.2f", invoice.amount))"
        content.sound = .default
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create a unique identifier
        let identifier = "due-soon-\(invoice.id.uuidString)"
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling due date notification: \(error.localizedDescription)")
            }
        }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}