//
//  CameraCaptureView.swift
//  SiteVantage
//
//  Wraps UIImagePickerController with sourceType = .camera ONLY. There is
//  no PHPickerViewController anywhere in this app and no way to select an
//  existing photo from the library — the picker is configured so the only
//  path in is the live camera, per spec §4 screen 4.
//

import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

struct CameraUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Unavailable")
                .font(.title3.bold())
            Text("This device/simulator has no camera. Evidence capture requires a live camera \u{2014} there is no gallery fallback in SiteVantage.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}
