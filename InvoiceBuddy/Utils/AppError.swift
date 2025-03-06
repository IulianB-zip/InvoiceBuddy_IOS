//
//  AppError.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


import Foundation
import SwiftUI

enum AppError: Error, LocalizedError {
    case databaseError(String)
    case scanningError(String)
    case notificationError(String)
    case networkError(String)
    case validationError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseError(let message):
            return "Database Error: \(message)"
        case .scanningError(let message):
            return "Scanning Error: \(message)"
        case .notificationError(let message):
            return "Notification Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        }
    }
}


