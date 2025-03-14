// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager()
    @State private var selectedTab = 0
    
    var body: some View {
        GeometryReader { geometry in
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
            .accentColor(.blue)
            .onAppear {
                // Configure TabBar appearance to fill edges
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithDefaultBackground()
                UITabBar.appearance().standardAppearance = tabBarAppearance
                
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                }
                
                // Remove the top border line
                UITabBar.appearance().shadowImage = UIImage()
                UITabBar.appearance().backgroundImage = UIImage()
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .onAppear {
            dataManager.loadAll()
        }
    }
}

// This is a wrapper view that decides which scanner view to use
struct ScannerView: View {
    var body: some View {
        ImprovedScannerView()
    }
}
