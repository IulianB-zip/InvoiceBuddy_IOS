import SwiftUI
import UIKit

/// A completely redesigned tab bar with no bottom gap
struct CompleteTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme
    
    // Tab bar properties
    private let tabBarItems: [(image: String, selectedImage: String, text: String)] = [
        ("doc.text", "doc.text.fill", "Invoices"),
        ("chart.bar", "chart.bar.fill", "Dashboard"),
        ("camera", "camera.fill", "Scan"),
        ("creditcard", "creditcard.fill", "Payment"),
        ("gear", "gear.fill", "Settings")
    ]
    
    var body: some View {
        // Use UIKit integration to get real safe area values
        TabBarWithBackground(selectedTab: $selectedTab, items: tabBarItems)
    }
}

/// UIViewRepresentable wrapper to get exact safe area insets and handle background properly
struct TabBarWithBackground: UIViewRepresentable {
    @Binding var selectedTab: Int
    let items: [(image: String, selectedImage: String, text: String)]
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        // Get coordinator reference
        let coordinator = context.coordinator
        
        // Add tab bar overlay in exact position
        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.filter({$0.isKeyWindow}).first {
                self.configureTabBar(in: view, window: window, coordinator: coordinator)
            } else if let window = UIApplication.shared.windows.first {
                self.configureTabBar(in: view, window: window, coordinator: coordinator)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update selected tab if needed
        if let stackView = uiView.subviews.first?.subviews.compactMap({ $0 as? UIStackView }).first {
            for (index, arrangedSubview) in stackView.arrangedSubviews.enumerated() {
                if let button = arrangedSubview as? UIButton {
                    updateButton(button, isSelected: index == selectedTab, item: items[index])
                }
            }
        }
    }
    
    private func updateButton(_ button: UIButton, isSelected: Bool, item: (image: String, selectedImage: String, text: String)) {
        // Update colors
        button.tintColor = isSelected ? .systemBlue : .gray
        button.setTitleColor(isSelected ? .systemBlue : .gray, for: .normal)
        
        // Update image
        let imageName = isSelected ? item.selectedImage : item.image
        if let image = UIImage(systemName: imageName) {
            button.setImage(image, for: .normal)
        }
    }
    
    private func configureTabBar(in view: UIView, window: UIWindow, coordinator: Coordinator) {
        // Get the exact safe area insets
        let safeAreaInsets = window.safeAreaInsets
        
        // Create blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = CGRect(
            x: 0,
            y: 0,
            width: window.frame.width,
            height: 60 + safeAreaInsets.bottom // Include bottom safe area
        )
        
        // Add top border
        let borderView = UIView(frame: CGRect(x: 0, y: 0, width: window.frame.width, height: 0.5))
        borderView.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        blurView.contentView.addSubview(borderView)
        
        // Add stack view for tab items
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .fill
        stackView.frame = CGRect(x: 0, y: 8, width: window.frame.width, height: 50)
        
        // Add tab buttons
        for (index, item) in items.enumerated() {
            let button = self.createTabButton(item: item, index: index, isSelected: index == selectedTab)
            button.tag = index
            button.addTarget(coordinator, action: #selector(Coordinator.tabButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        
        // Add views to hierarchy
        blurView.contentView.addSubview(stackView)
        view.addSubview(blurView)
    }
    
    private func createTabButton(item: (image: String, selectedImage: String, text: String), index: Int, isSelected: Bool) -> UIButton {
        let button = UIButton(type: .custom)
        
        // Configure button
        if let image = UIImage(systemName: isSelected ? item.selectedImage : item.image) {
            button.setImage(image, for: .normal)
        }
        button.setTitle(item.text, for: .normal)
        button.tintColor = isSelected ? .systemBlue : .gray
        button.setTitleColor(isSelected ? .systemBlue : .gray, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 10)
        
        // Stack image and title vertically
        button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -30, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: -10, left: 0, bottom: 8, right: 0)
        
        // Set size
        if index == 2 {
            // Center tab (Scan) has slightly larger icon
            button.imageView?.contentMode = .scaleAspectFit
            button.imageView?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
        
        return button
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: TabBarWithBackground
        
        init(_ parent: TabBarWithBackground) {
            self.parent = parent
        }
        
        @objc func tabButtonTapped(_ sender: UIButton) {
            parent.selectedTab = sender.tag
        }
    }
}

/// Main tab view with completely fixed layout
struct CompleteMainTabView: View {
    @State private var selectedTab = 0 // Default to "Invoices" tab
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Tab content
                TabContent(selectedTab: $selectedTab)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .edgesIgnoringSafeArea(.bottom)
                
                // Custom tab bar overlay with real UIKit components
                VStack {
                    Spacer()
                    CompleteTabBar(selectedTab: $selectedTab)
                        .frame(height: 83) // Height includes the bottom safe area
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
    }
}

/// Tab content view
struct TabContent: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        ZStack {
            // Invoices tab
            if selectedTab == 0 {
                NavigationView {
                    ImprovedInvoiceListView()
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Dashboard tab
            else if selectedTab == 1 {
                NavigationView {
                    Text("Dashboard Content")
                        .navigationTitle("Dashboard")
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Scan tab
            else if selectedTab == 2 {
                ImprovedScannerView()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Payment tab
            else if selectedTab == 3 {
                NavigationView {
                    Text("Payment Content")
                        .navigationTitle("Payment")
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Settings tab
            else if selectedTab == 4 {
                NavigationView {
                    SettingsView()
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
    }
}
