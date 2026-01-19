import CoreML
import Foundation
import Vision
import SwiftUI
import UIKit


class ColonyPredictor{
    static func createImageClassifier() -> VNCoreMLModel {
        let config = MLModelConfiguration()
//        guard let wrapper = try? UTIObjectDetector_2_Iteration_3000(configuration: config) else {
//            fatalError("Failed to load ML model")
//        }
        guard let wrapper = try? _11m_40_640(configuration: config) else {
            fatalError("Failed to load ML model")
        }
        guard let vnModel = try? VNCoreMLModel(for: wrapper.model) else {
            fatalError("Failed to create VNCoreMLModel")
        }
        return vnModel
    }
    
    private static let classifier = createImageClassifier()
    
    struct Prediction: Hashable, Identifiable {
        let id: UUID = UUID()
        let classification: String
        let confidence: String
        let coordinates: CGRect
    }
    
    typealias imagePredictionHandler = (_ predictions: [Prediction]?) -> Void
    
    private var predictionHandlers = [VNRequest: imagePredictionHandler]()
    
    private func createImageClassificationRequest() -> VNImageBasedRequest {
        let request = VNCoreMLRequest(model: ColonyPredictor.classifier, completionHandler: requestHandler)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }
    
    func makePrediction(for image: UIImage, completionHandler: @escaping imagePredictionHandler) throws {
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        
        let request = createImageClassificationRequest()
        predictionHandlers[request] = completionHandler
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, orientation: orientation!)
        let requests: [VNRequest] = [request]
        try handler.perform(requests)
    }
    
    private func requestHandler(_ request: VNRequest, error: Error?) {
        guard let handler = predictionHandlers.removeValue(forKey: request) else {
            return
        }
        
        var predictions: [Prediction]? = nil
        
        defer {
            handler(predictions)
        }
        
        if let error = error{
            print(error)
            return
        }
        
        if request.results == nil{
            print("No results")
            return
        }
        
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            return
        }
        
        predictions = observations.map { observation in
            Prediction(classification: observation.labels.first!.identifier, confidence: String(observation.confidence), coordinates: observation.boundingBox)
        }
        print(observations.debugDescription)
        
    }
    
    
    
    
}

