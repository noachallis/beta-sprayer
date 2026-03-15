import SwiftUI

// CameraView wraps UIKit's UIImagePickerController so we can use the camera in SwiftUI.
// UIImagePickerController is a UIKit view controller — UIViewControllerRepresentable
// is a SwiftUI protocol that lets us wrap it.
//
// NOTE: The camera only works on a real iPhone. It will crash on the Simulator.
// Use the photo library picker in ContentView for testing on Simulator.
struct CameraView: UIViewControllerRepresentable {

    /// The image to write to when the user takes a photo
    @Binding var image: UIImage?

    /// Dismiss is used to close the camera sheet when done
    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera          // use the camera (not the photo library)
        picker.delegate = context.coordinator
        return picker
    }

    // We don't need to update the controller after creation
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    /// The Coordinator handles callbacks from UIImagePickerController
    /// (UIKit uses a "delegate" pattern instead of SwiftUI's closures)
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        /// Called when the user takes a photo and confirms it
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let photo = info[.originalImage] as? UIImage {
                parent.image = photo
            }
            parent.dismiss()
        }

        /// Called when the user taps Cancel
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
