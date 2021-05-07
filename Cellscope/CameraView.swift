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


// Object to save an image to iPhone's photo library
// From https://www.hackingwithswift.com/books/ios-swiftui/how-to-save-images-to-the-users-photo-library
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

// This is the main view of the application
// Contains the logic for uploading/downloading to/from S3 and
// running image processing algorithms locally on the iPhone
struct CameraView: View {
    
    var group = DispatchGroup()     // for asynchronous invocation of certain functions
    
    @State var imageCounter = 2         // keep track of number for image key, initially updated to bucket size+1
    private let imageSaver = ImageSaver()       // to save image to photo library
    @State var imagesInS3Bucket = [String]()    // list of image keys in S3 bucket
    
    @State var shouldShowImagePicker = false
    @State var image: UIImage?
    
    @State var shouldShowBrightfieldImage = false
    @State var brightfieldImage: UIImage?
    
    @State var shouldShowDifferentialPhaseContrastImage = false
    @State var differentialPhaseContrastImage: UIImage?
    
    @State var shouldShowThresholdingImage = false
    @State var thresholdingImage: UIImage?
    
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
                Button(action: thresholdingButton, label: {
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
        .sheet(isPresented: $shouldShowThresholdingImage, content: {
            ImagePicker(image: $thresholdingImage)
        })
//        .onAppear {
//            listItemsInBucketFolder()
//        }
    }
    
    @State var listenToken: AnyCancellable?
    func listItemsInBucketFolder(folder: String) -> [String]{
        var items = [String]()
        listenToken = Amplify.Storage.list().resultPublisher.sink {
            if case let .failure(storageError) = $0 {
                print("Failed: \(storageError.errorDescription). \(storageError.recoverySuggestion)")
            }
            }
            receiveValue: { listResult in
                listResult.items.forEach { item in
                    if item.key.hasPrefix(folder) &&
                        (item.key.hasSuffix(".jpg") || item.key.hasSuffix(".png")) {
//                        DispatchQueue.main.async {
//                            self.imagesInS3Bucket.append(item.key)
//                        }
                        items.append(item.key)
                    }
                }
            }
        return items
    }
    
    func takePhotoButton() {
        if let image = self.image {
//            upload(image: image, subfolder: "unprocessed")
        }
        else {
            shouldShowImagePicker.toggle()
        }
    }
    
    // upload an image to AWS S3 bucket
    func upload(image: UIImage, path: String){
        var done = false
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {return}
//        let key = subfolder + "/sample" + String(imageCounter) + ".jpg"
        
        _ = Amplify.Storage.uploadData(key: path, data: imageData) { result in
            switch result {
            case .success:
                print("Uploaded image!")
                imageCounter += 1
                done = true
//                let post = Post(imageKey: key)
//                save(post)
            
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
    
    @State var downloadToken: AnyCancellable?
    func downloadImage(imageKey: String) {
        downloadToken = Amplify.Storage.downloadData(key: imageKey).resultPublisher.sink(
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                let image = UIImage(data: data)
                print("IMAGE KEY: \(imageKey)")
                    
                DispatchQueue.main.async {
                    self.imageSaver.writeToPhotoAlbum(image: image!)
                }
            })
    }
    
    @State var brightfieldSize = 0
    @State var image1: UIImage?
    @State var image2: UIImage?
    @State var cancellableBF1: AnyCancellable?
    @State var cancellableBF2: AnyCancellable?
    
    func brightfieldButton() {
        if let image = self.brightfieldImage {
            if image1 == nil {
                image1 = image
            }
            else if image1 != nil && image2 == nil {
                image2 = image
            }
            else if image1 != nil && image2 != nil {
                brightfieldProcessing(image1: self.image1!, image2: self.image2!)
            }
            upload(image: image, path: "unprocessed/brightfield/sample\(brightfieldSize+1).jpg")
            self.brightfieldSize += 1
            if brightfieldSize > 1 {
                
                sleep(10)
                group.enter()
                brightfieldS3Download(path: "processed/brightfield/bfresult+1.jpg")
                group.leave()
            }
        }
        else {
            shouldShowBrightfieldImage.toggle()
        }
    }
    
    func brightfieldS3Download(path: String) {
        let storageOperation = Amplify.Storage.downloadData(key: path)
        cancellableBF1 = storageOperation.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                guard let image = SwiftImage.Image<RGBA<UInt8>>(data: data)?.uiImage else {return}
                self.brightfieldImage = image
                DispatchQueue.main.async {
                    imageSaver.writeToPhotoAlbum(image: image)
                }
                print("Image data - \(data)")
            })
    }
    
    
    // download two images from unprocessed/samples/ and run bf processing algorithm
//    func brightfieldDownload() {
//        imageCounter -= 1
//        let storageOperation1 = Amplify.Storage.downloadData(key: "unprocessed/sample\(imageCounter).jpg")
//        cancellableBF1 = storageOperation1.resultPublisher.sink (
//            receiveCompletion: {completion in
//                if case .failure(let error) = completion{
//                    print(error)
//                }
//            },
//            receiveValue: {data in
//                self.imageData1 = data
//                print("Image data 1 - \(data)")
//            })
//
//        imageCounter -= 1
//        let storageOperation2 = Amplify.Storage.downloadData(key: "unprocessed/sample\(imageCounter).jpg")
//        cancellableBF2 = storageOperation2.resultPublisher.sink (
//            receiveCompletion: {completion in
//                if case .failure(let error) = completion{
//                    print(error)
//                }
//            },
//            receiveValue: {data in
//                self.imageData2 = data
//                DispatchQueue.main.async {
//                    brightfieldProcessing(leftData: self.imageData1, rightData: self.imageData2)
//                }
//                print("Image data 2 - \(data)")
//            })
//
//        shouldShowBrightfieldImage.toggle()
//    }
    
    func brightfieldProcessing(image1: UIImage, image2: UIImage) {
        let leftImage = SwiftImage.Image<RGBA<UInt8>>(uiImage: image1).resizedTo(width: 100, height: 100)
        let rightImage = SwiftImage.Image<RGBA<UInt8>>(uiImage: image2).resizedTo(width: 100, height: 100)
        
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
        
        self.brightfieldImage = SwiftImage.Image<RGBA<UInt8>>(width: 100, height: 100, pixels: pixels).uiImage
        self.imageSaver.writeToPhotoAlbum(image: self.brightfieldImage!)
//        DispatchQueue.main.async {
//            upload(image: self.brightfieldImage!, subfolder: "brightfield")
//        }
        
        print("-----Brightfield processing DONE-----")
    }
    
    @State var cancellableDPC1: AnyCancellable?
    @State var cancellableDPC2: AnyCancellable?
    
    func differentialPhaseContrastButton() {
//        differentialPhaseContrastDownload()
//        shouldShowDifferentialPhaseContrastImage.toggle()
        if let image = self.differentialPhaseContrastImage {
//            upload(image: image, subfolder: "unprocessed/dpc")
            sleep(10)
            differentialPhaseContrastDownload()
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
//            upload(image: self.image!, subfolder: "dpc")
        }
        
        print("-----Differential Phase Contrast processing DONE-----")
    }
    
    @State var cancellableTH: AnyCancellable?

    func thresholdingButton() {
        if let image = self.thresholdingImage {
//            let currentSize = listItemsInBucketFolder(folder: "unprocessed/thresholding").count
            var currentSize = 0
//            DispatchQueue.global().sync {
//                upload(image: image, path: "unprocessed/thresholding/sample\(currentSize+1).jpg")
//            }
//
//            DispatchQueue.global().asyncAfter(deadline: .now()+10) {
//                thresholdingDownload(path: "processed/thresholding/threshholdresult\(currentSize+1).jpg")
//            }
            upload(image: image, path: "unprocessed/threshholding/sample\(currentSize+1).jpg")
            sleep(20)
            group.enter()
            thresholdingDownload(path: "processed/threshholding/threshholdresult\(currentSize+1).jpg")
            group.leave()
            currentSize += 1
        }
        else {
            shouldShowThresholdingImage.toggle()
        }
    }

    func thresholdingDownload(path: String) {
//        imageCounter -= 1
        let storageOperation2 = Amplify.Storage.downloadData(key: path)
        cancellableTH = storageOperation2.resultPublisher.sink (
            receiveCompletion: {completion in
                if case .failure(let error) = completion{
                    print(error)
                }
            },
            receiveValue: {data in
                guard let image = SwiftImage.Image<RGBA<UInt8>>(data: data)?.uiImage else {return}
                self.thresholdingImage = image
                DispatchQueue.main.async {
                    imageSaver.writeToPhotoAlbum(image: image)
                }
                print("Image data - \(data)")
            })

//        shouldShowThresholdingImage.toggle()
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
