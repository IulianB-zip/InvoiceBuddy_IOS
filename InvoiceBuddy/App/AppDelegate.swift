//
//  AppDelegate.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 05.03.2025.
//


// AppDelegate.swift
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        return true
    }
}

// InvoiceModel.swift
import Foundation
import CoreData

enum PaymentStatus: String, Codable {
    case pending = "Pending"
    case paid = "Paid"
    case overdue = "Overdue"
}

enum PaymentMethod: String, Codable, CaseIterable {
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case bankTransfer = "Bank Transfer"
    case cash = "Cash"
    case other = "Other"
}

struct Invoice: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var amount: Double
    var dueDate: Date
    var status: PaymentStatus = .pending
    var paymentMethod: PaymentMethod?
    var reminderDate: Date?
    var barcode: String?
    var qrData: String?
    var notes: String?
    var priority: Int = 0 // Higher number means higher priority
    var isPaid: Bool = false
    var paymentDate: Date?
    var associatedCardId: String?
}

// DataManager.swift
import Foundation
import CoreData
import SwiftUI

class DataManager: ObservableObject {
    @Published var invoices: [Invoice] = []
    @Published var paymentMethods: [PaymentMethod] = PaymentMethod.allCases
    @Published var userCards: [Card] = []
    @Published var monthSettings: [MonthSetting] = []
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "InvoiceManager")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Load data
        loadInvoices()
        loadCards()
        loadMonthSettings()
    }
    
    func loadInvoices() {
        // Load from Core Data
    }
    
    func saveInvoice(_ invoice: Invoice) {
        // Save to Core Data
        
        // Schedule notification
        scheduleReminderForInvoice(invoice)
    }
    
    func deleteInvoice(at offsets: IndexSet) {
        // Delete from Core Data
    }
    
    func updateInvoiceStatus() {
        // Check for overdue invoices
        let today = Date()
        for i in 0..<invoices.count {
            if invoices[i].dueDate < today && invoices[i].status == .pending {
                invoices[i].status = .overdue
            }
        }
    }
    
    // Card methods
    func loadCards() {
        // Load cards from Core Data
    }
    
    func saveCard(_ card: Card) {
        // Save card to Core Data
    }
    
    func deleteCard(at offsets: IndexSet) {
        // Delete card from Core Data
    }
    
    // Month settings
    func loadMonthSettings() {
        // Load month settings from Core Data
    }
    
    func saveMonthSetting(_ setting: MonthSetting) {
        // Save month setting to Core Data
    }
    
    // Notification scheduling
    func scheduleReminderForInvoice(_ invoice: Invoice) {
        guard let reminderDate = invoice.reminderDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Invoice Payment Reminder"
        content.body = "\(invoice.title) is due tomorrow. Amount: $\(String(format: "%.2f", invoice.amount))"
        content.sound = .default
        
        let calendar = Calendar.current
        var reminderComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        reminderComponents.hour = 9 // Notify at 9 AM
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
        let request = UNNotificationRequest(identifier: invoice.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    // Prioritize invoices based on due date and payday
    func prioritizeInvoices(payday: Date) {
        // Implement prioritization algorithm
    }
}

// Card.swift
import Foundation

struct Card: Identifiable, Codable {
    var id = UUID()
    var name: String
    var type: CardType
    var lastFourDigits: String
    var expiryDate: Date
    var isDefault: Bool = false
}

enum CardType: String, Codable, CaseIterable {
    case credit = "Credit"
    case debit = "Debit"
}

// MonthSetting.swift
import Foundation

struct MonthSetting: Identifiable, Codable {
    var id = UUID()
    var year: Int
    var month: Int
    var isCritical: Bool = false
    var isLowIncome: Bool = false
    var note: String?
    var annualExpenses: [AnnualExpense] = []
}

struct AnnualExpense: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var dueDate: Date
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject var dataManager = DataManager()
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

// InvoiceListView.swift (Simplified version)
import SwiftUI

struct InvoiceListView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddInvoice = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataManager.invoices.sorted(by: { $0.dueDate < $1.dueDate })) { invoice in
                    InvoiceRow(invoice: invoice)
                }
                .onDelete(perform: dataManager.deleteInvoice)
            }
            .navigationTitle("Invoices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInvoice = true }) {
                        Label("Add Invoice", systemImage: "plus")
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

struct InvoiceRow: View {
    var invoice: Invoice
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(invoice.title)
                    .font(.headline)
                Text(invoice.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(String(format: "%.2f", invoice.amount))")
                    .font(.headline)
                Text(formattedDate(invoice.dueDate))
                    .font(.caption)
                    .foregroundColor(dueDateColor(invoice.dueDate))
            }
        }
        .padding(.vertical, 4)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func dueDateColor(_ date: Date) -> Color {
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if daysUntilDue < 0 {
            return .red
        } else if daysUntilDue <= 3 {
            return .orange
        } else {
            return .green
        }
    }
}

// ScannerView.swift
import SwiftUI
import AVFoundation
import Vision

struct ScannerView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var isScanning = false
    @State private var scannedData: String?
    @State private var showingAddInvoice = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isScanning {
                    CameraView(scannedData: $scannedData, isScanning: $isScanning)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera")
                            .font(.system(size: 72))
                            .foregroundColor(.blue)
                        
                        Text("Scan invoice QR code or barcode")
                            .font(.headline)
                        
                        Button(action: {
                            isScanning = true
                        }) {
                            Text("Start Scanning")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Scan Invoice")
            .onChange(of: scannedData) { newValue in
                if let data = newValue {
                    // Process scanned data
                    // This is where you would parse the QR/barcode data
                    print("Scanned data: \(data)")
                    showingAddInvoice = true
                }
            }
            .sheet(isPresented: $showingAddInvoice) {
                if let data = scannedData {
                    AddInvoiceView(prefillData: data)
                        .environmentObject(dataManager)
                }
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var scannedData: String?
    @Binding var isScanning: Bool
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func didFindScannedData(_ data: String) {
            parent.scannedData = data
            parent.isScanning = false
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didFindScannedData(_ data: String)
}

class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean13, .ean8, .code128]
        } else {
            failed()
            return
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = captureSession
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }
    
    private func failed() {
        let alert = UIAlertController(title: "Scanning Not Supported", message: "Your device does not support scanning barcodes or QR codes.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didFindScannedData(stringValue)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
}