//
//  ContentView.swift
//  UTIColonoyCounting
//
//  Created by M. De Vries on 23/10/2025.
//

import SwiftUI
import SwiftData
import PhotosUI
import MijickCamera
import MijickTimer
import Charts
import CoreML
import CoreVideo
import CoreImage
internal import Combine
import UIKit

class ViewModel: ObservableObject{
    @Published var ErrorHandle: Bool = false
    @Published var ErrorMessage: String = "Oops... Something went wrong!"
    @Published var Path: [ViewType] = []
    @Published var Image: UIImage?
    let colonyPredictor: ColonyPredictor = ColonyPredictor()
    @Published var Predictions: [ColonyPredictor.Prediction] = []
    @Published var requiredAccuracy: Float = 0.75
    
    func resetViewModel(){
        self.ErrorHandle = false
        self.ErrorMessage = "Oops... Something went wrong!"
        self.Image = nil
        self.Predictions = []
    }
}

enum ViewType: String {
    case Camera, Picker, Analysis, Result
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State var navigationIndex: Int = 0
    
    @StateObject var viewModel: ViewModel = ViewModel()
    
    var body: some View {
        NavigationStack(path: $viewModel.Path){
            VStack{
                //                Text("This App is intended as a proof of concept for an accessible solution to qualitative analysis of urine culture")
                Spacer()
                Text("©️ 2025 M. de Vries")
                    .padding(.all)
                NavigationLink(value: ViewType.Camera){
                    Text("Take Photo")
                        .foregroundStyle(.white)
                }
                .padding(.all)
                .background(.selection)
                .cornerRadius(15)
                
                PickerView(viewModel: viewModel)
            }.navigationTitle("Colony Counting")
                .alert("Something went wrong!", isPresented: $viewModel.ErrorHandle) {
                    Button(role: .close) {
                        viewModel.resetViewModel()
                    } label: {
                        Text("Dismiss")
                    }
                } message: {
                    Text(viewModel.ErrorMessage)
                }
                .navigationDestination(for: ViewType.self, destination: { type in
                    switch type{
                    case .Camera:
                        CameraView(viewModel: viewModel)
                    case .Analysis:
                        AnalysisView(viewModel: viewModel)
                    case .Result:
                        ResultView(viewModel: viewModel)
                    default:
                        Text("Oops, something went wrong!")
                    }
                })

        }
    }
}

#Preview {
    ContentView(viewModel: ViewModel())
        .modelContainer(for: Item.self, inMemory: true)
}

struct PickerView: View{
    @Environment(\.isPresented) var isPresented: Bool
    @State var pickerItems: [PhotosPickerItem] = []
    @State var visible: Bool = false
    @State var imageSelection: PhotosPickerItem?
    @State var image: UIImage?
    let maxSelection: Int = 1
    
    @ObservedObject var viewModel: ViewModel
    
    func loadTransferable(from imageSelection: PhotosPickerItem) -> Progress {
        return imageSelection.loadTransferable(type: Data.self) { result in
                guard imageSelection == self.imageSelection else { return }
                switch result {
                case .success(let image?):
                    // Handle the success case with the image.
                    self.image = UIImage(data: image)
                    viewModel.Image = self.image
                    viewModel.Path = [.Analysis]

                case .success(nil):
                    print("No image loaded")
                    viewModel.ErrorMessage = "Failed to load selection."
                    viewModel.ErrorHandle = true
                    // Handle the success case with an empty value.
                case .failure(let error):
                    print("Failure")
                    viewModel.ErrorMessage = "Failed to load selection: \(error.localizedDescription)"
                    viewModel.ErrorHandle = true
                    // Handle the failure case with the provided error.
                }
            
        }
    }
    
    var body: some View{
        PhotosPicker(selection: $pickerItems, maxSelectionCount: maxSelection, selectionBehavior: .ordered, matching: .images, preferredItemEncoding: .automatic) {
            Text("Select Image for Analysis")
                .padding(.all)
        }
        .onChange(of: pickerItems) { oldValue, newValue in
            if pickerItems.count != 0{
                _ = loadTransferable(from: pickerItems.first!)
                
            }
        }
    }
}

struct CameraView: View{
    @State var visible: Bool = false
    
    @ObservedObject var viewModel: ViewModel
    var body: some View{
        MCamera()
            .setCameraOutputType(.photo)
            .setAudioAvailability(false)
            .setCameraScreen(CustomCameraScreen.init)
            .onImageCaptured { img, controller in
                controller.closeMCamera()
                visible = true
                if let image = img.cgImage{
                    print("image: w:\(image.width), h: \(image.height)")
                    let width: Int
                    let height: Int
                    if image.width >= image.height{
                        width = image.height
                        height = image.width
                        if let cropped = image.cropping(to: CGRect(x: (height - width) / 2 , y: 0, width: width, height: width)){
                            viewModel.Image = UIImage(cgImage: cropped)
                            viewModel.Path = [.Analysis]
                        }
                    } else {
                        width = image.width
                        height = image.height
                        if let cropped = image.cropping(to: CGRect(x: 0, y: (height - width) / 2 , width: width, height: width)){
                            viewModel.Image = UIImage(cgImage: cropped)
                            viewModel.Path = [.Analysis]
                        }
                    }

                }
            }
            .startSession()
    }
}

struct AnalysisView: View{
    @State var image: UIImage?
    @State var inProgress: Bool = false
    
    @ObservedObject var viewModel: ViewModel
    
    func analyse(){
        guard let image = viewModel.Image else {
            viewModel.ErrorMessage = "No image selected for ColonyPredictor"
            viewModel.Path = []
            viewModel.ErrorHandle = true
            return
        }
        /*
        viewModel.colonyPredictor.makePrediction(for: image, completionHandler: self)
        let detector = try? UTIObjectDetector_2_Iteration_3000(configuration: .init())
        if let image = image{
            let buffer = image.convertToBuffer()
            if let buffer = buffer{
                do {
                    let output = try detector?.prediction(image: buffer, iouThreshold: 0.5, confidenceThreshold: 0.50)
                    viewModel.DetectorOutput = output
                } catch {
                    print(error)
                    viewModel.ErrorMessage = "Something went wrong whilst running the model: \(error.localizedDescription)"
                    viewModel.ErrorHandle = true
                }
            }
        }
        */
        do {
            inProgress = true
            try viewModel.colonyPredictor.makePrediction(for: image) { predictions in
                // Handle predictions here (save or update state as needed)
                // Example: print them, or update a @State var for display
                inProgress = false
                // Optionally, process the predictions (save to ViewModel, etc)
                print("predictions: \(predictions?.debugDescription ?? "")")
                if let predictions = predictions{
                    viewModel.Predictions = predictions
                }
                viewModel.Path = [.Result]
            }
        } catch {
            inProgress = false
            viewModel.ErrorMessage = "Failed to run prediction: \(error.localizedDescription)"
            viewModel.ErrorHandle = true
        }
        
    }
    
    var body: some View{
        if let image = viewModel.Image{
            ZStack{
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
//                    .padding(.all)
                VStack{
                    Spacer()
                    if inProgress{
                        ProgressView()
                            .padding(.all)
                            .background(.white)
                            .opacity(0.5)
                            .cornerRadius(15)
                            .navigationBarBackButtonHidden()
                            .navigationTitle(Text("Analysis"))
                    } else {
                        Button(action: {withAnimation() {
                            inProgress = true
                            analyse()
                        }}){
                            Text("Count Colonies")
                            .foregroundStyle(.white)
                               
                        }
                            .padding(.all)
                            .background(.selection)
                            .cornerRadius(15)
                    }
                    }
            }
                .navigationTitle(Text("Confirm"))
                
        } else {
            Text("AnalysisView")
                .onAppear(){
                    if viewModel.Image == nil{
                        viewModel.Path = []
                    }
                }
        }
    }
}

struct CustomCameraScreen: MCameraScreen {
    @ObservedObject var cameraManager: CameraManager
    
    let namespace: Namespace.ID
    let closeMCameraAction: () -> ()


    var body: some View {
        ZStack() {
            createNavigationBar()
            createCameraOutputView()
//            createCircle()
            createCaptureButton()
        }
    }
}
private extension CustomCameraScreen {
    func createNavigationBar() -> some View {
        Text("This is a Custom Camera View")
            .padding(.top, 12)
            .padding(.bottom, 12)
    }
    func createCaptureButton() -> some View {
        Button(action: captureOutput) { Circle()
                .fill(Color.white)
                .opacity(0.8)
                .frame(width: 375, height: 375)
                .scaledToFit()
        }
            .padding(.top, 12)
            .padding(.bottom, 12)
    }
//    func createCircle() -> some View{
//        Circle()
//            .border(Color(uiColor: .white))
//    }
}

struct ResultView: View{
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: ViewModel
    @State var confidentCount: Int = 0
    
    func getConfidentCount() -> Int{
        var count = 0
        for prediction in viewModel.Predictions{
            if Float(prediction.confidence)! >= viewModel.requiredAccuracy{
                count += 1
            }
        }
        return count
    }
    
    var body: some View{
        List{
//            VStack{
            Section("Results"){
                Chart(){
                    BarMark(x: .value("Confidence", "All"), y: .value("Number of Colonies", viewModel.Predictions.count))
                    BarMark(x: .value("Confidence", "Met"), y: .value("Number of Colonies", confidentCount))
                }
            }
                Section("Annotated Sample"){
                            if let image = viewModel.Image{
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .overlay {
                                            GeometryReader{ reader in
                                                ForEach(viewModel.Predictions, id: \.self) { prediction in
                                                    if Float(prediction.confidence) ?? 0 >= viewModel.requiredAccuracy{
                                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                            .fill(.white)
                                                            .frame(width: prediction.coordinates.size.width * reader.size.width, height: prediction.coordinates.size.height * reader.size.width, alignment: .bottomTrailing)
                                                            .position(x: (prediction.coordinates.origin.x) * reader.size.width + prediction.coordinates.size.width * reader.size.width, y: (1 - prediction.coordinates.origin.y) * reader.size.height - prediction.coordinates.size.height * reader.size.height)
                                                            .foregroundStyle(Color.white)
                                                            .opacity(0.5)
                                                    }
                                                }
                                            }
                                        }
                                        .border(.blue, width: 3)
                                }
                    }
            Section("Predictions") {
                Text("Confidence: \(viewModel.requiredAccuracy)")
                Slider(value: $viewModel.requiredAccuracy, in: 0...1)
                ForEach(viewModel.Predictions, id: \.self) { prediction in
                    Text("\(prediction.classification): \(prediction.confidence)")
                }
                .onChange(of: viewModel.requiredAccuracy) {
                    confidentCount = getConfidentCount()
                }
                .onAppear(){
                    confidentCount = getConfidentCount()
                }
            }
        }
        .navigationTitle(Text("Results"))
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem {
                Button(action: {
                    viewModel.Path = []
                }) {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}




struct ColonyData: Identifiable{
    var type: String
    var count: Int
    var id: UUID = UUID()
}







//Source: https://www.createwithswift.com/uiimage-cvpixelbuffer-converting-an-uiimage-to-a-pixelbuffer/
import Foundation
import UIKit

extension UIImage {
        
    func convertToBuffer() -> CVPixelBuffer? {
        
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer)
        
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(
            data: pixelData,
            width: Int(self.size.width),
            height: Int(self.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

