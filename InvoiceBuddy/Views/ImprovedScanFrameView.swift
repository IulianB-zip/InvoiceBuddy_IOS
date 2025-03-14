// ImprovedScanFrameView.swift
import SwiftUI

/// Enhanced scan frame with visual guides to help user position invoices correctly
struct ImprovedScanFrameView: View {
    var body: some View {
        ZStack {
            // Semitransparent overlay around frame
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .inset(by: 3)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Frame outline
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
            
            // Corner indicators for better visual guidance
            VStack {
                HStack {
                    CornerIndicator()
                    Spacer()
                    CornerIndicator(rotation: .degrees(90))
                }
                
                Spacer()
                
                HStack {
                    CornerIndicator(rotation: .degrees(270))
                    Spacer()
                    CornerIndicator(rotation: .degrees(180))
                }
            }
            .padding(5)
            
            // Guidance text at the bottom
            VStack {
                Spacer()
                Text("Position the invoice fully inside the frame")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(.bottom, 10)
            }
        }
    }
}

/// Corner indicator with L-shaped path for scan frame visual guides
struct CornerIndicator: View {
    var rotation: Angle = .zero
    
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 20))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 20, y: 0))
            }
            .stroke(Color.green, lineWidth: 4)
            .frame(width: 20, height: 20)
            .rotationEffect(rotation)
        }
        .frame(width: 30, height: 30)
    }
}

struct ImprovedScanFrameView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            ImprovedScanFrameView()
                .frame(width: 300, height: 400)
        }
        .previewLayout(.fixed(width: 400, height: 600))
    }
}
