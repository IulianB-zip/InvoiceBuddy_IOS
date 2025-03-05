//
//  AppError.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// AppError.swift
import Foundation

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

// ErrorHandling.swift
import Foundation
import SwiftUI

struct ErrorAlert: Identifiable {
    var id = UUID()
    var title: String
    var message: String
    var dismissAction: (() -> Void)? = nil
}

extension View {
    func withErrorHandling(error: Binding<Error?>, action: @escaping () -> Void = {}) -> some View {
        let errorAlert = Binding<ErrorAlert?>(
            get: {
                guard let error = error.wrappedValue else { return nil }
                return ErrorAlert(
                    title: "Error",
                    message: error.localizedDescription,
                    dismissAction: {
                        error.wrappedValue = nil
                        action()
                    }
                )
            },
            set: { _ in error.wrappedValue = nil }
        )
        
        return alert(item: errorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"), action: alert.dismissAction)
            )
        }
    }
}