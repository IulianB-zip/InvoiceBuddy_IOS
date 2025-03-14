import SwiftUI
import AVFoundation

/// A completely custom camera implementation that avoids using system UI
struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isScanning: Bool
    @Binding var errorMessage: String?
    @Binding var flashOn: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController()
        controller.delegate = context.coordinator
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CustomCameraController, context: Context) {
        uiViewController.setFlashMode(on: flashOn)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CustomCameraViewControllerDelegate {
        var parent: CustomCameraView
        
        init(_ parent: CustomCameraView) {
            self.parent = parent
        }
        
        func cameraViewController(_ controller: CustomCameraController, didCapture image: UIImage?) {
            parent.capturedImage = image
            if image != nil {
                // Not dismissing the camera here - let the parent view handle this
                // when it processes the image
            } else {
                parent.errorMessage = "Failed to capture image"
            }
        }
        
        func cameraViewControllerDidCancel(_ controller: CustomCameraController) {
            parent.isScanning = false
        }
    }
}
