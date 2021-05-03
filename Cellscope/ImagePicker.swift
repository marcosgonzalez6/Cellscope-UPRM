//
//  ImagePicker.swift
//  Cellscope
//
//  Created by marcos joel gonzález on 4/29/21.
//

import SwiftUI

struct ImagePicker: UIViewControllerRepresentable{
    
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    typealias UIViewControllerType = UIImagePickerController
    
    func makeCoordinator() -> (ImagePickerCoordinator) {
        ImagePickerCoordinator(imagePicker: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .photoLibrary
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let imagePicker: ImagePicker
    
    init(imagePicker: ImagePicker) {
        self.imagePicker = imagePicker
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePicker.presentationMode.wrappedValue.dismiss()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imagePicker.presentationMode.wrappedValue.dismiss()
        
        guard let image = info[.originalImage] as? UIImage else {return}
        imagePicker.image = image
    }
}
