//
//  CellscopeApp.swift
//  Cellscope
//
//  Created by marcos joel gonzález on 4/29/21.
//
//  adapted from Kilo Loco's tutorial: https://www.youtube.com/watch?v=i9QPG-4QiwM
//

import SwiftUI
import Amplify
import AmplifyPlugins


@main
struct CellscopeApp: App {
    
    init() {
        configureAmplify()
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                CameraView()
                    .tabItem {Image(systemName: "camera")}
                GalleryView()
                    .tabItem {Image(systemName: "photo.on.rectangle")}
            }
        }
    }
    
    func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            
            let models = AmplifyModels()
            try Amplify.add(plugin: AWSAPIPlugin(modelRegistration: models))
            try Amplify.add(plugin: AWSDataStorePlugin(modelRegistration: models))
            
            try Amplify.configure()
            print("Amplify configured with plugins")
            
        } catch {
            print("Could not configure Amplify - \(error)")
        }
    }
}
