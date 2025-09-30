//
//  ModelTester.swift
//  Test the CoreML model integration
//

import CoreML
import Foundation

class ModelTester {
    private var model: MLModel?

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly

            // Load model using generic MLModel instead of generated class
            if let modelURL = Bundle.main.url(
                forResource: "UltraSimpleCSLModel", withExtension: "mlpackage")
            {
                model = try MLModel(contentsOf: modelURL, configuration: config)
                print("✅ UltraSimpleCSLModel loaded successfully")
            } else {
                print("❌ Could not find UltraSimpleCSLModel.mlpackage in bundle")
            }
        } catch {
            print("❌ Failed to load model: \(error)")
        }
    }

    func testModel() -> Bool {
        guard let model = model else {
            print("❌ Model not loaded")
            return false
        }

        do {
            // Create test input (50 frames of 512 features)
            let featuresArray = try MLMultiArray(
                shape: [NSNumber(value: 1), NSNumber(value: 50), NSNumber(value: 512)],
                dataType: .float32)
            let lengthsArray = try MLMultiArray(
                shape: [NSNumber(value: 1)],
                dataType: .int32)

            // Fill with random test data
            for i in 0..<featuresArray.count {
                featuresArray[i] = NSNumber(value: Float.random(in: -1...1))
            }
            lengthsArray[0] = NSNumber(value: 50)

            // Create input dictionary for generic MLModel
            let inputFeatures: [String: Any] = [
                "features": featuresArray,
                "lengths": lengthsArray,
            ]

            let input = try MLDictionaryFeatureProvider(dictionary: inputFeatures)

            // Run prediction
            let startTime = CFAbsoluteTimeGetCurrent()
            let output = try model.prediction(from: input)
            let inferenceTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            // Extract embeddings from generic output
            guard let embeddingsFeature = output.featureValue(for: "embeddings"),
                let embeddings = embeddingsFeature.multiArrayValue
            else {
                print("❌ Could not extract embeddings from model output")
                return false
            }

            print("✅ Model test successful!")
            print("📊 Output shape: \(embeddings.shape)")
            print("⏱️ Inference time: \(String(format: "%.2f", inferenceTime))ms")

            return true

        } catch {
            print("❌ Model test failed: \(error)")
            return false
        }
    }
}
