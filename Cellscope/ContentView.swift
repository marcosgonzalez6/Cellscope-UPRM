//
//  ContentView.swift
//  Cellscope
//
//  Created by marcos joel gonzález on 4/29/21.
//

import SwiftUI
import Amplify
import AmplifyPlugins

struct ContentView: View {
    
    @State var fileStatus: String?
    
    var body: some View {
        if let fileStatus = self.fileStatus {
            Text(fileStatus)
        }
        Button("Upload file", action: uploadFile).padding()
    }
    
    func uploadFile() {
        let fileKey = "mytest.txt"
        let fileContents = "Contents testing here and now"
        let fileData = fileContents.data(using: .utf8)!
        
        Amplify.Storage.uploadData(
            key: fileKey,
            data: fileData
        ) { result in
            
            switch result {
            case .success(let key):
                print("file with key \(key) uploaded")
                
                DispatchQueue.main.async {
                    fileStatus = "File uploaded"
                }
                
            case .failure(let storageError):
                print("Failed to upload file", storageError)
                
                DispatchQueue.main.async {
                    fileStatus = "Failed to upload file"
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
