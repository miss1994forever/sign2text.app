//
//  FeatureExtractor.swift
//  Feature extraction from video frames for sign language translation
//

import UIKit
import Vision
import CoreML
import AVFoundation

class FeatureExtractor: ObservableObject {
    @Published var isExtracting = false
    @Published var extractionProgress: Double = 0.0
    
    private var resnetModel: VNCoreMLModel?
    
    init() {
        setupResNetModel()
    }
    
    // MARK: - Setup
    
    private func setupResNetModel() {
        do {
            // Use built-in ResNet50 for feature extraction
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            
            // You can use any of these pre-trained models:
            // - Resnet50 (2048 features)
            // - MobileNetV2 (1280 features) 
            // - EfficientNet (varies)
            
            // For now, we'll create a simple custom feature extractor
            resnetModel = try VNCoreMLModel(for: createSimpleFeatureExtractor())
            print("✅ Feature extraction model loaded")
            
        } catch {
            print("❌ Failed to load feature extraction model: \(error)")
        }
    }
    
    private func createSimpleFeatureExtractor() -> MLModel {
        // This is a placeholder - you would load a real pre-trained model
        // For demo purposes, we'll create a dummy model structure
        fatalError("Implement with real feature extraction model")
    }
}

// MARK: - Main Feature Extraction Methods

extension FeatureExtractor {
    
    /// Extract features from a sequence of video frames
    func extractFeatures(from frames: [UIImage], maxFrames: Int = 50) async -> [[Float]]? {
        guard !frames.isEmpty else { return nil }
        
        await MainActor.run {
            isExtracting = true
            extractionProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isExtracting = false
                extractionProgress = 0.0
            }
        }
        
        // Limit frames to maxFrames and ensure consistent sampling
        let sampledFrames = sampleFrames(frames, targetCount: maxFrames)
        var features: [[Float]] = []
        
        for (index, frame) in sampledFrames.enumerated() {
            if let frameFeatures = await extractFeaturesFromSingleFrame(frame) {
                features.append(frameFeatures)
            } else {
                // If extraction fails, use zero features
                features.append(Array(repeating: 0.0, count: 512))
            }
            
            // Update progress
            let progress = Double(index + 1) / Double(sampledFrames.count)
            await MainActor.run {
                extractionProgress = progress
            }
        }
        
        // Pad to exactly maxFrames if needed
        while features.count < maxFrames {
            features.append(Array(repeating: 0.0, count: 512))
        }
        
        print("✅ Extracted features from \(sampledFrames.count) frames")
        return features
    }
    
    /// Extract features from a single frame
    private func extractFeaturesFromSingleFrame(_ image: UIImage) async -> [Float]? {
        return await withCheckedContinuation { continuation in
            // Method 1: Using Vision + Pre-trained CNN (Recommended)
            extractUsingVision(image) { features in
                continuation.resume(returning: features)
            }
        }
    }
}

// MARK: - Vision Framework Approach (Recommended)

extension FeatureExtractor {
    
    private func extractUsingVision(_ image: UIImage, completion: @escaping ([Float]?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
                // Using ResNet50 features as an example
        guard let model = resnetModel else {
            print("❌ ResNet model not available")
            completion(nil)
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("❌ Vision request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
                  let firstObservation = observations.first else {
                print("❌ No feature vector observations found")
                completion(nil)
                return
            }
            
            // Convert MLMultiArray to Float array
            let features = self.convertMLMultiArrayToFloatArray(firstObservation.featureValue.multiArrayValue)
            completion(features)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Failed to perform vision request: \(error)")
            completion(nil)
        }
    }
}

// MARK: - Manual CNN Approach (Alternative)

extension FeatureExtractor {
    
    /// Manual feature extraction using basic computer vision
    private func extractManualFeatures(_ image: UIImage) -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Resize image to standard size
        let targetSize = CGSize(width: 224, height: 224)
        guard let resizedImage = resizeImage(image, to: targetSize) else { return nil }
        
        var features: [Float] = []
        
        // Extract basic visual features
        features.append(contentsOf: extractColorFeatures(resizedImage))
        features.append(contentsOf: extractEdgeFeatures(resizedImage))
        features.append(contentsOf: extractTextureFeatures(resizedImage))
        features.append(contentsOf: extractMotionFeatures(resizedImage))
        
        // Pad or trim to exactly 512 features
        return resizeFeatureVector(features, targetSize: 512)
    }
    
    private func extractColorFeatures(_ image: UIImage) -> [Float] {
        // Extract color histograms, dominant colors, etc.
        // This is a simplified version
        var features: [Float] = []
        
        // RGB channel means
        if let pixelData = getPixelData(image) {
            let (r, g, b) = calculateChannelMeans(pixelData)
            features.append(contentsOf: [r, g, b])
        }
        
        // Color histogram (simplified)
        features.append(contentsOf: Array(repeating: Float.random(in: 0...1), count: 64))
        
        return features
    }
    
    private func extractEdgeFeatures(_ image: UIImage) -> [Float] {
        // Edge detection, contours, etc.
        // Simplified implementation
        return Array(repeating: Float.random(in: 0...1), count: 128)
    }
    
    private func extractTextureFeatures(_ image: UIImage) -> [Float] {
        // Texture analysis, patterns, etc.
        // Simplified implementation  
        return Array(repeating: Float.random(in: 0...1), count: 64)
    }
    
    private func extractMotionFeatures(_ image: UIImage) -> [Float] {
        // This would need previous frame for real motion detection
        // For single frame, extract position-related features
        return Array(repeating: Float.random(in: 0...1), count: 32)
    }
}

// MARK: - MediaPipe Integration (Advanced)

extension FeatureExtractor {
    
    /// Using MediaPipe for hand/pose detection (you'd need to add MediaPipe)
    private func extractUsingMediaPipe(_ image: UIImage) -> [Float]? {
        // This would require integrating MediaPipe framework
        // MediaPipe can detect:
        // - Hand landmarks (21 points × 3 coordinates = 63 features)
        // - Pose landmarks (33 points × 3 coordinates = 99 features) 
        // - Face landmarks (468 points × 3 coordinates = 1404 features)
        
        /*
        Example structure:
        1. Detect hand landmarks
        2. Normalize coordinates
        3. Extract relative positions, angles, distances
        4. Combine into feature vector
        */
        
        return nil // Implement with MediaPipe
    }
}

// MARK: - Utility Functions

extension FeatureExtractor {
    
    private func sampleFrames(_ frames: [UIImage], targetCount: Int) -> [UIImage] {
        guard frames.count > targetCount else { return frames }
        
        // Evenly sample frames
        let step = Double(frames.count) / Double(targetCount)
        var sampledFrames: [UIImage] = []
        
        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            let clampedIndex = min(index, frames.count - 1)
            sampledFrames.append(frames[clampedIndex])
        }
        
        return sampledFrames
    }
    
    private func resizeFeatureVector(_ features: [Float], targetSize: Int) -> [Float] {
        if features.count == targetSize {
            return features
        } else if features.count > targetSize {
            // Downsample
            let step = Double(features.count) / Double(targetSize)
            return (0..<targetSize).map { i in
                let index = Int(Double(i) * step)
                return features[min(index, features.count - 1)]
            }
        } else {
            // Upsample with interpolation or padding
            var result = features
            while result.count < targetSize {
                result.append(0.0)
            }
            return result
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    private func getPixelData(_ image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelData: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]
                pixelData.append(contentsOf: [r, g, b])
            }
        }
        
        return pixelData
    }
    
    private func calculateChannelMeans(_ pixelData: [UInt8]) -> (Float, Float, Float) {
        var rSum: Int = 0, gSum: Int = 0, bSum: Int = 0
        let pixelCount = pixelData.count / 3
        
        for i in stride(from: 0, to: pixelData.count, by: 3) {
            rSum += Int(pixelData[i])
            gSum += Int(pixelData[i + 1])  
            bSum += Int(pixelData[i + 2])
        }
        
        return (
            Float(rSum) / Float(pixelCount) / 255.0,
            Float(gSum) / Float(pixelCount) / 255.0,
            Float(bSum) / Float(pixelCount) / 255.0
        )
    }
    
    /// Convert MLMultiArray to Float array
    private func convertMLMultiArrayToFloatArray(_ multiArray: MLMultiArray?) -> [Float]? {
        guard let multiArray = multiArray else { return nil }
        
        let count = multiArray.count
        var floatArray: [Float] = []
        floatArray.reserveCapacity(count)
        
        // Convert based on the data type
        switch multiArray.dataType {
        case .float32:
            for i in 0..<count {
                floatArray.append(multiArray[i].floatValue)
            }
        case .double:
            for i in 0..<count {
                floatArray.append(Float(multiArray[i].doubleValue))
            }
        case .int32:
            for i in 0..<count {
                floatArray.append(Float(multiArray[i].int32Value))
            }
        default:
            // Handle other types by converting to float
            for i in 0..<count {
                floatArray.append(multiArray[i].floatValue)
            }
        }
        
        return floatArray
    }
}

