//
//  CameraPicker.swift
//  Mwallet
//
//  SwiftUI 에는 카메라 촬영 화면이 없어 UIImagePickerController 를 감싼다.
//  선교지에서는 영수증을 받자마자 찍는 경우가 많아 보관함과 함께 제공한다.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {

    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    // 카메라를 쓸 수 없는 환경(시뮬레이터 등)에서는 진입을 막아야 한다.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let onCapture: (Data) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = ReceiptImageProcessor.compress(image) else {
                onCancel()
                return
            }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
