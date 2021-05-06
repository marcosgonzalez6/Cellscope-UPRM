//
//  GalleryView.swift
//  Cellscope
//
//  Created by marcos joel gonzález on 4/29/21.
//

import Amplify
import Combine
import SwiftUI

struct GalleryView: View {
    
    @State var imageCache = [String: UIImage?]()
    
    var body: some View {
        List(imageCache.sorted(by: { $0.key > $1.key }), id: \.key) { key, image in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .onAppear {
//            getPosts()
//            observePosts()
            listen()
        }
    }
    
    func getPosts() {
        Amplify.DataStore.query(Post.self) { result in
            switch result {
            case .success(let posts):
                print(posts)
                
                downloadImages(for: posts)
                
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func downloadImages(for posts: [Post]) {
        for post in posts {
            
            _ = Amplify.Storage.downloadData(key: post.imageKey) { result in
                switch result {
                case .success(let imageData):
                    let image = UIImage(data: imageData)
                    
                    DispatchQueue.main.async {
                        imageCache[post.imageKey] = image
                    }
                    
                case .failure(let error):
                    print("Failed to download image data - \(error)")
                }
            }
        }
    }
    
    @State var token: AnyCancellable?
    func observePosts() {
        token = Amplify.DataStore.publisher(for: Post.self).sink(
            receiveCompletion: { print($0) },
            receiveValue: { event in
                do {
                    let post = try event.decodeModel(as: Post.self)
                    downloadImages(for: [post])
                    
                } catch {
                    print(error)
                }
            }
        )
    }
    
    @State var listenToken: AnyCancellable?
    func listen() {
        listenToken = Amplify.Storage.list().resultPublisher.sink {
            if case let .failure(storageError) = $0 {
                print("Failed: \(storageError.errorDescription). \(storageError.recoverySuggestion)")
            }
            }
            receiveValue: { listResult in
                listResult.items.forEach { item in
                    if item.key.hasSuffix(".jpg") {
                        downloadImage(imageKey: item.key)
                    }
                }
            }
    }
    
    func downloadImage(imageKey: String) {
        _ = Amplify.Storage.downloadData(key: imageKey) { result in
            switch result {
            case .success(let imageData):
                let image = UIImage(data: imageData)
                
                DispatchQueue.main.async {
                    imageCache[imageKey] = image
                }
                
            case .failure(let error):
                print("Failed to download image data - \(error)")
            }
        }
    }
    
//    func textToImage(drawText: NSString, inImage: UIImage, atPoint: CGPoint) -> UIImage{
//
//        let canvas = CGRect(x: 0, y: 0, width: inImage.size.width, height: inImage.size.height)
//        inImage.draw(in: canvas)
//
//        // Setup the font specific variables
//        var textColor = UIColor.white
//        var textFont = UIFont(name: "Helvetica Bold", size: 12)!
//
//        // Setup the image context using the passed image
//        let scale = UIScreen.mainScreen().scale
//        UIGraphicsBeginImageContextWithOptions(inImage.size, false, scale)
//
//        // Setup the font attributes that will be later used to dictate how the text should be drawn
//        let textFontAttributes = [
//            NSFontAttributeName: textFont,
//            NSForegroundColorAttributeName: textColor,
//        ]
//
//        // Put the image into a rectangle as large as the original image
//        inImage.drawInRect(CGRectMake(0, 0, inImage.size.width, inImage.size.height))
//
//        // Create a point within the space that is as bit as the image
//        var rect = CGRectMake(atPoint.x, atPoint.y, inImage.size.width, inImage.size.height)
//
//        // Draw the text into an image
//        drawText.drawInRect(rect, withAttributes: textFontAttributes)
//
//        // Create a new image out of the images we have created
//        var newImage = UIGraphicsGetImageFromCurrentImageContext()
//
//        // End the context now that we have the image we need
//        UIGraphicsEndImageContext()
//
//        //Pass the image back up to the caller
//        return newImage
//    }
}

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
}
