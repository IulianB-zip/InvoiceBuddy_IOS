//
//  InvoiceListView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// InvoiceListView.swift
import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddInvoice = false
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var searchText = ""
    
    enum InvoiceFilter {
        case all, pending, overdue, paid
        
        var title: String {
            switch self {
            case .all: return "All"
            case .pending: return "Pending"
            case .overdue: return "Overdue"
            case .paid: return "Paid"
            }
        }
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
            VStack {
                // Custom filter selector
                HStack {
                    ForEach([InvoiceFilter.all, .pending, .overdue, .paid], id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter.title)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search invoices", text: $searchText)
                        .disableAutocorrection(true)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if filteredInvoices.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No invoices found")
                            .font(.headline)
                        
                        if searchText.isEmpty {
                            Button(action: {
                                showingAddInvoice = true
                            }) {
                                Text("Add an invoice")
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(filteredInvoices) { invoice in
                            NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                                InvoiceRow(invoice: invoice)
                            }
                        }
                        .onDelete(perform: dataManager.deleteInvoice)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddInvoice = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                AddInvoiceView()
            }
            .onAppear {
                dataManager.loadInvoices()
            }
        }
    }
}

struct InvoiceRow: View {
    let invoice: Invoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.title)
                    .font(.headline)
                
                Text(invoice.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.formattedAmount)
                    .font(.headline)
                
                HStack {
                    Text(invoice.formattedDueDate)
                        .font(.caption)
                        .foregroundColor(dueDateColor)
                    
                    StatusIndicator(status: invoice.status)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var dueDateColor: Color {
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
