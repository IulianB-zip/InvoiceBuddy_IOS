//
//  ImprovedInvoiceListView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 13.03.2025.
//


import SwiftUI

/// An improved invoice list view with better spacing and layout
struct ImprovedInvoiceListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var searchText = ""
    @State private var showingAddInvoice = false
    
    // For better layout calculation
    @State private var listHeight: CGFloat = 0
    
    enum InvoiceFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case overdue = "Overdue"
        case paid = "Paid"
    }
    
    var filteredInvoices: [Invoice] {
        let filtered = dataManager.invoices.filter { invoice in
            if !searchText.isEmpty {
                return invoice.title.lowercased().contains(searchText.lowercased()) ||
                       invoice.description.lowercased().contains(searchText.lowercased())
            }
            return true
        }
        
        switch selectedFilter {
        case .all:
            return filtered.sorted { $0.dueDate < $1.dueDate }
        case .pending:
            return filtered.filter { $0.status == .pending }.sorted { $0.dueDate < $1.dueDate }
        case .overdue:
            return filtered.filter { $0.status == .overdue }.sorted { $0.dueDate < $1.dueDate }
        case .paid:
            return filtered.filter { $0.status == .paid }.sorted { ($0.paymentDate ?? Date()) > ($1.paymentDate ?? Date()) }
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Content header with fixed spacing
                    VStack(spacing: 16) {
                        // Filter buttons
                        FilterButtonRow(selectedFilter: $selectedFilter)
                            .padding(.horizontal, 16)
                        
                        // Search field
                        SearchField(searchText: $searchText)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Dynamic content area
                    ZStack {
                        if filteredInvoices.isEmpty {
                            // Empty state optimized for space
                            EmptyInvoicesView(showingAddInvoice: $showingAddInvoice)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Invoice list
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredInvoices) { invoice in
                                        NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                                            ImprovedInvoiceRow(invoice: invoice)
                                                .padding(.horizontal, 16)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.vertical, 12)
                                // Add bottom padding to account for tab bar
                                .padding(.bottom, 60)
                            }
                        }
                    }
                    .frame(width: geometry.size.width)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle("Invoices")
            .navigationBarItems(trailing: 
                Button(action: { showingAddInvoice = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
            )
            .sheet(isPresented: $showingAddInvoice) {
                AddInvoiceView()
            }
            .onAppear {
                dataManager.loadInvoices()
            }
        }
    }
}

// MARK: - Supporting Views

/// Filter button row with improved visual style
struct FilterButtonRow: View {
    @Binding var selectedFilter: ImprovedInvoiceListView.InvoiceFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ImprovedInvoiceListView.InvoiceFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.15))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

/// Improved search field
struct SearchField: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            TextField("Search invoices", text: $searchText)
                .padding(.vertical, 8)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// Empty state view with better vertical spacing
struct EmptyInvoicesView: View {
    @Binding var showingAddInvoice: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No invoices found")
                .font(.title3)
                .fontWeight(.medium)
            
            Button(action: {
                showingAddInvoice = true
            }) {
                Text("Add an invoice")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 4)
            
            Spacer()
            
            // Add spacer for tab bar
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Improved invoice row with better layout
struct ImprovedInvoiceRow: View {
    let invoice: Invoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(invoice.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(invoice.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(invoice.formattedAmount)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text(invoice.formattedDueDate)
                        .font(.caption)
                        .foregroundColor(dueDateColor(for: invoice))
                    
                    StatusIndicator(status: invoice.status)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func dueDateColor(for invoice: Invoice) -> Color {
        if invoice.status == .paid {
            return .secondary
        }
        
        let daysRemaining = invoice.daysUntilDue
        
        if daysRemaining < 0 {
            return .red
        } else if daysRemaining <= 2 {
            return .orange
        } else if daysRemaining <= 7 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct StatusIndicator: View {
    let status: PaymentStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    var backgroundColor: Color {
        switch status {
        case .pending:
            return .blue
        case .paid:
            return .green
        case .overdue:
            return .red
        }
    }
}