//
//  ScannedInvoiceData.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//

// ScannedData.swift
import Foundation

struct ScannedInvoiceData: Equatable {
    var rawData: String
    var title: String?
    var description: String?
    var amount: Double?
    var dueDate: Date?
    var barcode: String?
    var qrData: String?
    
    init(rawData: String) {
        self.rawData = rawData
        self.barcode = rawData
        self.qrData = rawData
        parseData()
    }
    
    static func == (lhs: ScannedInvoiceData, rhs: ScannedInvoiceData) -> Bool {
        return lhs.rawData == rhs.rawData &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description &&
               lhs.amount == rhs.amount &&
               lhs.dueDate == rhs.dueDate &&
               lhs.barcode == rhs.barcode &&
               lhs.qrData == rhs.qrData
    }
    
    mutating func parseData() {
        // Try to parse as JSON first
        if let jsonData = rawData.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    self.title = json["title"] as? String
                    self.description = json["description"] as? String
                    
                    if let amountString = json["amount"] as? String {
                        self.amount = Double(amountString)
                    } else {
                        self.amount = json["amount"] as? Double
                    }
                    
                    if let dueDateString = json["dueDate"] as? String {
                        let dateFormatter = DateFormatter()
                        // Try multiple date formats
                        let dateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd"]
                        
                        for format in dateFormats {
                            dateFormatter.dateFormat = format
                            if let date = dateFormatter.date(from: dueDateString) {
                                self.dueDate = date
                                break
                            }
                        }
                    }
                    return
                }
            } catch {
                // Not valid JSON, continue with other parsing methods
            }
        }
        
        // Try to parse as key-value pairs (e.g., "title=Electric Bill&amount=75.50&due=2023-04-15")
        let components = rawData.components(separatedBy: "&")
        
        for component in components {
            let keyValue = component.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0].lowercased()
                let value = keyValue[1]
                
                switch key {
                case "title":
                    self.title = value
                case "description", "desc":
                    self.description = value
                case "amount", "amt":
                    self.amount = Double(value)
                case "due", "duedate":
                    let dateFormatter = DateFormatter()
                    // Try multiple date formats
                    let dateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy/MM/dd"]
                    
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: value) {
                            self.dueDate = date
                            break
                        }
                    }
                default:
                    break
                }
            }
        }
        
        // If still no structured data found, try to extract information from text
        if title == nil && description == nil && amount == nil && dueDate == nil {
            extractInformationFromText()
        }
    }
    
    mutating func extractInformationFromText() {
        // Look for amount patterns (e.g., $123.45, 123.45 USD)
        let amountPattern = #"\$?(\d+(\.\d{1,2})?)\s*(USD|EUR|GBP)?"#
        if let amountMatch = rawData.range(of: amountPattern, options: .regularExpression) {
            let amountString = rawData[amountMatch].replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "USD", with: "")
                .replacingOccurrences(of: "EUR", with: "")
                .replacingOccurrences(of: "GBP", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.amount = Double(amountString)
        }
        
        // Look for date patterns
        let datePatterns = [
            #"\d{2}/\d{2}/\d{4}"#, // MM/DD/YYYY or DD/MM/YYYY
            #"\d{4}-\d{2}-\d{2}"#, // YYYY-MM-DD
            #"\d{2}-\d{2}-\d{4}"#  // MM-DD-YYYY or DD-MM-YYYY
        ]
        
        for pattern in datePatterns {
            if let dateMatch = rawData.range(of: pattern, options: .regularExpression) {
                let dateString = String(rawData[dateMatch])
                let dateFormatter = DateFormatter()
                
                if pattern == #"\d{2}/\d{2}/\d{4}"# {
                    dateFormatter.dateFormat = "MM/dd/yyyy" // Assuming MM/DD/YYYY format
                } else if pattern == #"\d{4}-\d{2}-\d{2}"# {
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                } else {
                    dateFormatter.dateFormat = "MM-dd-yyyy" // Assuming MM-DD-YYYY format
                }
                
                if let date = dateFormatter.date(from: dateString) {
                    self.dueDate = date
                    break
                }
            }
        }
        
        // Set a generic title if none was found
        if self.title == nil {
            if rawData.count > 30 {
                self.title = "Scanned Invoice"
                self.description = String(rawData.prefix(100))
            } else {
                self.title = rawData
            }
        }
    }
}
