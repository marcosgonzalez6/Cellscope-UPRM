//
//  CameraView.swift
//  Cellscope
//
//  Created by marcos joel gonzález on 4/29/21.
//
//  adapted from tutorial by Kilo Loco https://www.youtube.com/watch?v=i9QPG-4QiwM
//

import SwiftUI
import Amplify
import Combine
import SwiftImage

class ImageSaver: NSObject {
    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveError), nil)
    }
    @objc func saveError(_ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer) {
            print("Save finished!")
        }
}

struct CameraView: View {
    
    @State var imageCounter = 1
    private let imageSaver = ImageSaver()
    
    @State var shouldShowImagePicker = false
    @State var image: UIImage?
    
    @State var shouldShowBrightfieldImage = false
    @State var brightfieldImage: UIImage?
    
    @State var shouldShowDifferentialPhaseContrastImage = false
    @State var differentialPhaseContrastImage: UIImage?
    
    @State var shouldShowThreshholdingImage = false
    @State var threshholdingImage: UIImage?
    
    var body: some View {
        VStack {
            if let image = self.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            Spacer()
            Button(action: takePhotoButton, label: {
                let imageName = self.image == nil
                    ? "camera"
                    : "icloud.and.arrow.up"
                Image(systemName: imageName)
                    .font(.largeTitle)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
            })
            Spacer()
            HStack {
                Button(action: brightfieldButton, label: {
                    Text("Brightfield")
                })
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                Button(action: differentialPhaseContrastButton, label: {
                       Text("DPC")
                })
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(minWidth: 10.0)
            }
            HStack {
                Button(action: threshholdingButton, label: {
                    Text("Threshholding")
                })
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
//                Button(action: {}, label: {
//                       Text("Custom")
//                })
//                .padding()
//                .background(Color.blue)
//                .foregroundColor(.white)
//                .cornerRadius(8)
            }
            Spacer()
        }
        .sheet(isPresented: $shouldShowImagePicker, content: {
            ImagePicker(image: $image)
        })
        .sheet(isPresented: $shouldShowBrightfieldImage, content: {
            ImagePicker(image: $brightfieldImage)
        })
        .sheet(isPresented: $shouldShowDifferentialPhaseContrastImage, content: {
            ImagePicker(image: $differentialPhaseContrastImage)
        })
        .sheet(isPresented: $shouldShowThreshholdingImage, content: {
            ImagePicker(image: $threshholdingImage)
        })
        .onAppear {
            observePosts()
        }
    }
    
    func takePhotoButton() {
        if let image = self.image {
            upload(image: image, subfolder: "unprocessed")
        }
        else {
            shouldShowImagePicker.toggle()
        }
    }
    
    // upload an image to AWS S3 bucket
    func upload(image: UIImage, subfolder: String){
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {return}
        let key = subfolder + "/sample" + String(imageCounter) + ".jpg"
        
        _ = Amplify.Storage.uploadData(key: key, data: imageData) { result in
            switch result {
            case .success:
                print("Uploaded image!")
                imageCounter += 1
                
                let post = Post(imageKey: key)
                save(post)
            
            case .failure(let error):
                print("Failed to upload - \(error)")
            
            }
        }
    }
    
    // save post information to AWS DataStore
    func save(_ post: Post) {
        Amplify.DataStore.save(post) { result in
            switch result {
            case .success:
                print("Saved post!")
                self.image = nil
            
            case .failure(let error):
                print("Failed to save post - \(error)")
            
            }
        }
    }
    
    @State var cancellableObserve: AnyCancellable?
    func observePosts() {
        cancellableObserve = Amplify.DataStore.publisher(for: Post.self).sink(
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
    
    func downloadImages(for posts: [Post]) {
        for post in posts {
            
            _ = Amplify.Storage.downloadData(key: post.imageKey) { result in
                switch result {
                case .success(let imageData):
                    let image = UIImage(data: imageData)
                    print("IMAGE KEY: \(post.imageKey)")
                    
                    DispatchQueue.main.async {
                        self.image = image
                        
//                        if post.imageKey.starts(with: "brightfield") {
//                            self.brightfieldImage = image
//                        }
//                        else if post.imageKey.starts(with: "dpc") {
//                            self.differentialPhaseContrastImage = image
//                        }
//                        else if post.imageKey.starts(with: "processed/threshholding") {
//                            self.threshholdingImage = image
//                            self.imageSaver.writeToPhotoAlbum(image: image!)
//                        }
                        self.imageSaver.writeToPhotoAlbum(image: image!)
                    }
                    
                case .failure(let error):
                    print("Failed to download image data - \(error)")
                }
            }
            
        }
    }
    
    @State var imageData1 = Data()
    @State var imageData2 = Data()
    @State var cancellableBF1: AnyCancellable?
    @State var cancellableBF2: AnyCancellable?
    
    func brightfieldButton() {
//        brightfieldDownload()
//        shouldShowBrightfieldImage.toggle()
        if let image = self.brightfieldImage {
            upload(image: image, subfolder: "brightfield")
        }
        else {
            shouldShowBrightfieldImage.toggle()
        }
    }
    
    // download two images from unprocessed/samples/ and run bf processing algorithm
    func brightfieldDownload() {
        imageCounter -= 1
        let storageOperation1 = Amplify.Storage.downloadData(key: "unprocessed/sample\(imageCounter).jpg")
        cancellableBF1 = storageOperation1.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                self.imageData1 = data
                print("Image data 1 - \(data)")
            })
        
        imageCounter -= 1
        let storageOperation2 = Amplify.Storage.downloadData(key: "unprocessed/sample\(imageCounter).jpg")
        cancellableBF2 = storageOperation2.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                self.imageData2 = data
                DispatchQueue.main.async {
                    brightfieldProcessing(leftData: self.imageData1, rightData: self.imageData2)
                }
                print("Image data 2 - \(data)")
            })
        
        shouldShowBrightfieldImage.toggle()
    }
    
    func brightfieldProcessing(leftData: Data, rightData: Data) {
        guard let leftImage = SwiftImage.Image<RGBA<UInt8>>(data: leftData)?.resizedTo(width: 20, height: 20)
            else {return}
        guard let rightImage = SwiftImage.Image<RGBA<UInt8>>(data: rightData)?.resizedTo(width: 20, height: 20)
            else {return}
        
//        var pixels: [RGBA<UInt8>] = []
//        for x in 0...leftImage.height-1 {
//            for y in 0...leftImage.width-1 {
//                if y < leftImage.width/2 {
//                    pixels.append(leftImage[x,y])
//                }
//                else {
//                    pixels.append(rightImage[x,y])
//                }
//            }
//        }
        var pixels: [RGBA<UInt8>] = []
        for x in 0...leftImage.height-1 {
            for y in 0...rightImage.width-1 {
                let pixelsSum = [leftImage[x,y].red.addingReportingOverflow(rightImage[x,y].red).partialValue,
                                 leftImage[x,y].green.addingReportingOverflow(rightImage[x,y].green).partialValue,
                                 leftImage[x,y].blue.addingReportingOverflow(rightImage[x,y].blue).partialValue,
                                 leftImage[x,y].alpha.addingReportingOverflow(rightImage[x,y].alpha).partialValue]
                let tempPixel = RGBA(red: pixelsSum[0],
                                     green: pixelsSum[1],
                                     blue: pixelsSum[2],
                                     alpha: pixelsSum[3])
                pixels.append(tempPixel)
            }
        }
        
        self.brightfieldImage = SwiftImage.Image<RGBA<UInt8>>(width: 20, height: 20, pixels: pixels).uiImage
        self.imageSaver.writeToPhotoAlbum(image: self.brightfieldImage!)
        DispatchQueue.main.async {
            upload(image: self.brightfieldImage!, subfolder: "brightfield")
        }
        
        print("-----Brightfield processing DONE-----")
    }
    
    @State var cancellableDPC1: AnyCancellable?
    @State var cancellableDPC2: AnyCancellable?
    
    func differentialPhaseContrastButton() {
//        differentialPhaseContrastDownload()
//        shouldShowDifferentialPhaseContrastImage.toggle()
        if let image = self.differentialPhaseContrastImage {
            upload(image: image, subfolder: "dpc")
        }
        else {
            shouldShowDifferentialPhaseContrastImage.toggle()
        }
    }
    
    func differentialPhaseContrastDownload() {
        imageCounter -= 1
        let storageOperation1 = Amplify.Storage.downloadData(key: "unprocessed/sample\(imageCounter).jpg")
        cancellableDPC1 = storageOperation1.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                self.imageData1 = data
                print("Image data 1 - \(data)")
            })
        
        imageCounter -= 1
        let storageOperation2 = Amplify.Storage.downloadData(key: "unprocessed/sample\(imageCounter).jpg")
        cancellableDPC2 = storageOperation2.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                self.imageData2 = data
                DispatchQueue.main.async {
                    differentialPhaseContrastProcessing(data1: self.imageData1, data2: self.imageData2)
                }
                print("Image data 2 - \(data)")
            })
        
        shouldShowDifferentialPhaseContrastImage.toggle()
        
    }
    
    func differentialPhaseContrastProcessing(data1: Data, data2: Data) {
        guard let image1 = SwiftImage.Image<RGBA<UInt8>>(data: data1)?.resizedTo(width: 20, height: 20)
            else {return}
        guard let image2 = SwiftImage.Image<RGBA<UInt8>>(data: data2)?.resizedTo(width: 20, height: 20)
            else {return}
        
        var pixels: [RGBA<UInt8>] = []
        for x in 0...image1.height-1 {
            for y in 0...image1.width-1 {
                let pixelsSum = [image1[x,y].red.addingReportingOverflow(image2[x,y].red).partialValue,
                                 image1[x,y].green.addingReportingOverflow(image2[x,y].green).partialValue,
                                 image1[x,y].blue.addingReportingOverflow(image2[x,y].blue).partialValue,
                                 image1[x,y].alpha.addingReportingOverflow(image2[x,y].alpha).partialValue]
                let tempPixel = RGBA(red: pixelsSum[0],
                                     green: pixelsSum[1],
                                     blue: pixelsSum[2],
                                     alpha: pixelsSum[3])
                pixels.append(tempPixel)
            }
        }
        
        self.image = SwiftImage.Image<RGBA<UInt8>>(width: 20, height: 20, pixels: pixels).uiImage
        
        // save processed image to iPhone photo library
        self.imageSaver.writeToPhotoAlbum(image: self.image!)
        
        // upload image to S3 bucket in folder "dpc"
        DispatchQueue.main.async {
            upload(image: self.image!, subfolder: "dpc")
        }
        
        print("-----Differential Phase Contrast processing DONE-----")
    }
    
    @State var cancellableTH: AnyCancellable?

    func threshholdingButton() {
        if let image = self.threshholdingImage {
            upload(image: image, subfolder: "unprocessed/threshholding")
        }
        else {
            shouldShowThreshholdingImage.toggle()
        }
    }

    func threshholdingDownload() {
//        imageCounter -= 1
        let storageOperation2 = Amplify.Storage.downloadData(key: "threshholding/sample\(imageCounter).jpg")
        cancellableTH = storageOperation2.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                self.threshholdingImage = SwiftImage.Image<RGBA<UInt8>>(data: data)?.uiImage
//                DispatchQueue.main.async {
//                    threshholdingProcessing(data: self.imageData1)
//                }
                print("Image data 2 - \(data)")
            })

//        shouldShowThreshholdingImage.toggle()
    }

//    func threshholdingProcessing() {
//
//    }
    
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
