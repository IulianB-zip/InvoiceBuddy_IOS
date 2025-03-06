//
//  DashboardView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 06.03.2025.
//


// DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTimeframe: Timeframe = .month
    
    enum Timeframe {
        case week, month, year
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    HStack(spacing: 15) {
                        SummaryCard(
                            title: "Due Soon",
                            value: "\(dataManager.getUpcomingInvoices(limit: 5).count)",
                            color: .blue,
                            systemImage: "calendar"
                        )
                        
                        SummaryCard(
                            title: "Overdue",
                            value: "\(dataManager.getOverdueInvoices().count)",
                            color: .red,
                            systemImage: "exclamationmark.circle"
                        )
                        
                        SummaryCard(
                            title: "This Month",
                            value: dataManager.getTotalDueThisMonth().formatted(.currency(code: "USD")),
                            color: .green,
                            systemImage: "dollarsign.circle"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Upcoming Invoices
                    DashboardSection(title: "Upcoming Invoices", systemImage: "calendar") {
                        ForEach(dataManager.getUpcomingInvoices(limit: 5)) { invoice in
                            NavigationLink(destination: InvoiceDetailView(invoice: invoice)) {
                                UpcomingInvoiceRow(invoice: invoice)
                            }
                        }
                        
                        if dataManager.getUpcomingInvoices().isEmpty {
                            HStack {
                                Spacer()
                                Text("No upcoming invoices")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                    
                    // Monthly Overview
                    DashboardSection(title: "Monthly Overview", systemImage: "chart.bar.fill") {
                        HStack {
                            Picker("Timeframe", selection: $selectedTimeframe) {
                                Text("Week").tag(Timeframe.week)
                                Text("Month").tag(Timeframe.month)
                                Text("Year").tag(Timeframe.year)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                        }
                        
                        // Monthly spending chart would go here
                        // Using a placeholder for now
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                Text("Monthly Spending Chart")
                                    .foregroundColor(.secondary)
                            )
                            .padding(.horizontal)
                    }
                    
                    // Critical Months
                    if !criticalMonths.isEmpty {
                        DashboardSection(title: "Critical Months", systemImage: "exclamationmark.triangle") {
                            ForEach(criticalMonths, id: \.id) { setting in
                                CriticalMonthRow(setting: setting)
                            }
                        }
                    }
                    
                    // Payment Methods Distribution
                    DashboardSection(title: "Payment Methods", systemImage: "creditcard.fill") {
                        if paymentMethodDistribution.isEmpty {
                            HStack {
                                Spacer()
                                Text("No payment data available")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 20) {
                                ForEach(Array(paymentMethodDistribution.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { method in
                                    VStack {
                                        Text("\(Int(paymentMethodDistribution[method] ?? 0))%")
                                            .font(.headline)
                                        
                                        Text(method.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Paydays Section
                    DashboardSection(title: "Upcoming Paydays", systemImage: "calendar.badge.clock") {
                        if dataManager.paydays.isEmpty {
                            HStack {
                                Spacer()
                                Text("No paydays configured")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                            
                            NavigationLink(destination: SettingsView()) {
                                Text("Configure paydays in settings")
                                    .foregroundColor(.blue)
                                    .padding(.horizontal)
                            }
                        } else {
                            ForEach(upcomingPaydays) { payday in
                                HStack {
                                    Text("Payday")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text(payday.formattedDate)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .onAppear {
                dataManager.loadAll()
            }
        }
    }
    
    // Calculate critical months
    var criticalMonths: [MonthSetting] {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        
        return dataManager.monthSettings
            .filter { $0.year >= currentYear && ($0.isCritical || $0.isLowIncome) }
            .sorted { setting1, setting2 in
                if setting1.year != setting2.year {
                    return setting1.year < setting2.year
                } else {
                    return setting1.month < setting2.month
                }
            }
    }
    
    // Calculate upcoming paydays
    var upcomingPaydays: [Payday] {
        let today = Date()
        return dataManager.paydays
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map { $0 }
    }
    
    // Calculate payment method distribution
    var paymentMethodDistribution: [PaymentMethod: Double] {
        var distribution: [PaymentMethod: Int] = [:]
        let paidInvoices = dataManager.invoices.filter { $0.status == .paid }
        let totalPaid = paidInvoices.count
        
        if totalPaid == 0 {
            return [:]
        }
        
        for invoice in paidInvoices {
            if let method = invoice.paymentMethod {
                distribution[method, default: 0] += 1
            }
        }
        
        var percentages: [PaymentMethod: Double] = [:]
        for (method, count) in distribution {
            percentages[method] = (Double(count) / Double(totalPaid)) * 100
        }
        
        return percentages
    }
}

// Dashboard components
struct SummaryCard: View {
    var title: String
    var value: String
    var color: Color
    var systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct DashboardSection<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            
            content()
            
            Divider()
                .padding(.top, 5)
        }
        .padding(.vertical, 10)
    }
}

struct UpcomingInvoiceRow: View {
    var invoice: Invoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.title)
                    .font(.headline)
                
                Text("Due \(invoice.formattedDueDate)")
                    .font(.caption)
                    .foregroundColor(dueDateColor)
            }
            
            Spacer()
            
            Text(invoice.formattedAmount)
                .font(.headline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    var dueDateColor: Color {
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

struct CriticalMonthRow: View {
    var setting: MonthSetting
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(setting.displayName)
                        .font(.headline)
                    
                    HStack {
                        if setting.isCritical {
                            Label("Critical", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if setting.isLowIncome {
                            Label("Low Income", systemImage: "dollarsign.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                if !setting.annualExpenses.isEmpty {
                    Text(setting.totalAnnualExpenses.formatted(.currency(code: "USD")))
                        .font(.headline)
                }
            }
            
            if let note = setting.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
