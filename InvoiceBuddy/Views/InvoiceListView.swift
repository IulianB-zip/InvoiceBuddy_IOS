//
//  InvoiceListView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// InvoiceListView.swift
import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddInvoice = false
    @State private var searchText = ""
    @State private var filterStatus: PaymentStatus? = nil
    
    var filteredInvoices: [Invoice] {
        dataManager.invoices.filter { invoice in
            let matchesSearch = searchText.isEmpty || 
                invoice.title.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || invoice.status == filterStatus
            return matchesSearch && matchesFilter
        }.sorted { $0.dueDate < $1.dueDate }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredInvoices) { invoice in
                    InvoiceRow(invoice: invoice)
                }
                .onDelete(perform: dataManager.deleteInvoice)
            }
            .searchable(text: $searchText, prompt: "Search invoices")
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInvoice = true }) {
                        Label("Add Invoice", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All", action: { filterStatus = nil })
                        ForEach(PaymentStatus.allCases, id: \.self) { status in
                            Button(status.rawValue, action: { filterStatus = status })
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                AddInvoiceView()
                    .environmentObject(dataManager)
            }
        }
    }
}