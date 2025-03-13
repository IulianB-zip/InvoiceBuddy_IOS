//
//  RefinedScanFrameView.swift
//  InvoiceBuddy
//
//  Created by Iulian Bucatariu on 13.03.2025.
//


import SwiftUI

/// A more refined scanning frame specifically for invoices
struct RefinedScanFrameView: View {
    var frameWidth: CGFloat = 280
    var frameHeight: CGFloat = 400
    
    @State private var scanLinePosition: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay to darken the area outside the scan frame
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    ZStack {
                        Rectangle()
                        
                        // Punch-through for the scan area
                        RoundedRectangle(cornerRadius: 8)
                            .frame(width: frameWidth, height: frameHeight)
                            .blendMode(.destinationOut)
                    }
                )
            
            // Main frame outline - using a white border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: frameWidth, height: frameHeight)
            
            // Corner brackets - simple and clean
            CornerMarks()
                .frame(width: frameWidth, height: frameHeight)
            
            // Animated scan line
            if isAnimating {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .white.opacity(0.8), .clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: frameWidth, height: 2)
                    .offset(y: scanLinePosition)
            }
            
            // Add a text guide below the frame
            VStack {
                Spacer()
                    .frame(height: frameHeight + 30)
                
                Text("Position the invoice inside the frame")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            startScanAnimation()
        }
    }
    
    private func startScanAnimation() {
        // Reset position before starting animation
        scanLinePosition = -frameHeight/2
        isAnimating = true
        
        // Animate the scan line from top to bottom
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            scanLinePosition = frameHeight/2
        }
    }
}

/// Corner marks for the scan frame
struct CornerMarks: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top left corner
                VStack(alignment: .leading) {
                    HStack {
                        cornerMark(rotation: 0)
                        Spacer()
                    }
                    Spacer()
                }
                
                // Top right corner
                VStack(alignment: .trailing) {
                    HStack {
                        Spacer()
                        cornerMark(rotation: 90)
                    }
                    Spacer()
                }
                
                // Bottom left corner
                VStack(alignment: .leading) {
                    Spacer()
                    HStack {
                        cornerMark(rotation: 270)
                        Spacer()
                    }
                }
                
                // Bottom right corner
                VStack(alignment: .trailing) {
                    Spacer()
                    HStack {
                        Spacer()
                        cornerMark(rotation: 180)
                    }
                }
            }
        }
    }
    
    private func cornerMark(rotation: Double) -> some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white)
                .frame(width: 20, height: 2)
                .offset(x: 10, y: 0)
            
            // Vertical line
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 20)
                .offset(x: 0, y: 10)
        }
        .rotationEffect(.degrees(rotation))
        .padding(5)
    }
}

/// Preview for the refined scan frame
struct RefinedScanFrameView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            RefinedScanFrameView()
        }
    }
}