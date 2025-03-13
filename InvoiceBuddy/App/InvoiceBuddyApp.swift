//
//  InvoiceBuddyApp.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 13.03.2025.
//

import SwiftUI
import AVFoundation
import PhotosUI

@main
struct InvoiceBuddyApp: App {
    // Shared data manager that can be accessed throughout the app
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            // Use the completely fixed tab view
            CompleteMainTabView()
                .environmentObject(dataManager)
                .onAppear {
                    // Initial data loading
                    dataManager.loadAll()
                    
                    // Request camera permissions early
                    requestCameraPermission()
                    
                    // Force extend background to edges on all screens
                    UITabBar.appearance().backgroundColor = UIColor.clear
                    UITabBar.appearance().isTranslucent = true
                }
        }
    }
    
    /// Request camera permission when app launches
    private func requestCameraPermission() {
        // Only request if not already determined
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                // Permission result handled when needed
            }
        }
    }
}
/// Integration steps:
/// 1. Replace the current scanner implementation with FixedScannerView
/// 2. Use MainTabView as your app's root view
/// 3. Add the CustomTabBar to handle tab navigation
/// 4. Update InvoiceListView and other tab content as needed

/// Implementation Notes:
///
/// Fixed Issues:
/// - Button overlap with system UI is eliminated
/// - Tab bar no longer conflicts with camera controls
/// - Single capture button (no duplication)
/// - Proper flash control that works
///
/// Key Features:
/// - Clean, focused camera view
/// - Properly positioned controls
/// - Better visual hierarchy
/// - Improved error handling
/// - Consistent design language

/// Troubleshooting Common Integration Issues:
///
/// Problem: Camera doesn't activate on the Scan tab
/// Solution: Ensure proper camera permissions in Info.plist:
///   <key>NSCameraUsageDescription</key>
///   <string>We need camera access to scan invoices</string>
///
/// Problem: Buttons still not working
/// Solution: Make sure NotificationCenter observers are properly set up in CameraSessionViewController
///
/// Problem: UI elements positioned incorrectly on different devices
/// Solution: Use GeometryReader and dynamic spacing instead of fixed values
///
/// Problem: Tab bar appears on top of camera UI
/// Solution: Use ZStack with proper layering and ensure tab content fills the screen

/// Additional Customization Options:
///
/// 1. To customize the scan frame appearance:
///    - Modify InvoiceScanFrame in FixedScannerView.swift
///
/// 2. To change the tab bar appearance:
///    - Update CustomTabBar in MainTabView.swift
///
/// 3. To adjust camera settings:
///    - Modify CameraSessionViewController configuration
