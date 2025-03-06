//
//  Payday.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// PaydayModel.swift
import Foundation

struct Payday: Identifiable, Codable {
    var id = UUID()
    var date: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var dayOfMonth: Int {
        return Calendar.current.component(.day, from: date)
    }
    
    var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7  // 1 = Sunday, 7 = Saturday
    }
}
