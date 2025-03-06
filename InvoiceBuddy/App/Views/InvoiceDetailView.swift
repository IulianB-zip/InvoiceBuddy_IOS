//
//  InvoiceDetailView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//




// InvoiceDetailView.swift
import SwiftUI

struct InvoiceDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @State var invoice: Invoice
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(invoice.title)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(invoice.description)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusIndicator(status: invoice.status)
                            .scaleEffect(1.2)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(invoice.formattedAmount)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Due Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(invoice.formattedDueDate)
                                .font(.headline)
                                .foregroundColor(invoice.isOverdue ? .red : .primary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Additional Details
                GroupBox(label: Label("Details", systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let paymentMethod = invoice.paymentMethod {
                            DetailRow(key: "Payment Method", value: paymentMethod.rawValue)
                        }
                        
                        if invoice.status == .paid, let paymentDate = invoice.paymentDate {
                            DetailRow(key: "Payment Date", value: formatDate(paymentDate))
                        }
                        
                        if let reminderDate = invoice.reminderDate {
                            DetailRow(key: "Reminder", value: formatDate(reminderDate))
                        }
                        
                        if let associatedCardId = invoice.associatedCardId, let card = findAssociatedCard(id: associatedCardId) {
                            DetailRow(key: "Card", value: "\(card.name) (\(card.lastFourDigits))")
                        }
                        
                        if let notes = invoice.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(notes)
                                    .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Barcode/QR Info
                if let barcode = invoice.barcode, !barcode.isEmpty {
                    GroupBox(label: Label("Scan Data", systemImage: "barcode")) {
                        VStack(alignment: .leading) {
                            Text("Barcode/QR Data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(barcode)
                                .font(.caption)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Action Buttons
                if invoice.status != .paid {
                    Button(action: {
                        markAsPaid()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Mark as Paid")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Invoice Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        isEditing = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditInvoiceView(invoice: $invoice)
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Invoice"),
                message: Text("Are you sure you want to delete this invoice? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteInvoice()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func findAssociatedCard(id: String) -> Card? {
        return dataManager.userCards.first(where: { $0.id.uuidString == id })
    }
    
    private func markAsPaid() {
        dataManager.markInvoiceAsPaid(invoice)
        invoice.status = .paid
        invoice.isPaid = true
        invoice.paymentDate = Date()
    }
    
    private func deleteInvoice() {
        dataManager.deleteInvoice(at: [dataManager.invoices.firstIndex(where: { $0.id == invoice.id })!])
        presentationMode.wrappedValue.dismiss()
    }
}

struct DetailRow: View {
    var key: String
    var value: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
        }
    }
}
