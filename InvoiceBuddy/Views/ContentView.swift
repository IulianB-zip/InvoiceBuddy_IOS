//
//  ContentView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var invoiceViewModel: InvoiceViewModel
    
    var body: some View {
        TabView {
            InvoiceListView()
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
            
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
            
            ScannerView()
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
            
            PaymentMethodsView()
                .tabItem {
                    Label("Payment", systemImage: "creditcard")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
