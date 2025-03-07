//
//  ContentView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            InvoiceListView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Invoices", systemImage: "doc.text")
                }
                .tag(0)
            
            DashboardView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(1)
            
            ScannerView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
                .tag(2)
            
            PaymentMethodsView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Payment", systemImage: "creditcard")
                }
                .tag(3)
            
            SettingsView()
                .environmentObject(dataManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
    }
}