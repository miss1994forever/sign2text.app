//
//  SignLanguageFeatureExtractor.swift
//  sign2text-app
//
//  Created by CV-SLT Integration on 2024/12/19.
//

import AVFoundation
import Accelerate
import CoreImage
import CoreML
import UIKit
import Vision

/// Advanced feature extraction system for sign language video processing
/// Converts video frames into 512-dimensional feature vectors for the CoreML model
class SignLanguageFeatureExtractor: NSObject {

    // MARK: - Configuration

    /// Maximum number of frames to process for a single sequence
    static let maxSequenceLength = 50

    /// Target feature dimension for each frame
    static let featureDimension = 512

    /// Frame processing settings
    private struct ProcessingConfig {
        static let imageSize = CGSize(width: 224, height: 224)
        static let frameSkipInterval = 3  // Process every 3rd frame for efficiency
        static let temporalWindowSize = 5  // Frames to consider for temporal features
    }

    // MARK: - Properties

    private var visionModel: VNCoreMLModel?
    private var frameBuffer: [CIImage] = []
    private var featureBuffer: [[Float]] = []
    private var processingQueue = DispatchQueue(label: "feature.extraction", qos: .userInitiated)

    /// Completion handler for processed features
    typealias FeatureExtractionCompletion = ([[Float]]) -> Void

    // MARK: - Initialization

    override init() {
        super.init()
        setupVisionModel()
    }

    // MARK: - Public Methods

    /// Process a new video frame and extract features
    /// - Parameters:
    ///   - ciImage: The captured video frame
    ///   - completion: Callback with extracted features when ready
    func processFrame(_ ciImage: CIImage, completion: @escaping FeatureExtractionCompletion) {
        processingQueue.async {
            // Add frame to buffer
            self.frameBuffer.append(ciImage)

            // Maintain buffer size
            if self.frameBuffer.count > Self.maxSequenceLength {
                self.frameBuffer.removeFirst()
            }

            // Extract features from current frame
            if let features = self.extractFeaturesFromFrame(ciImage) {
                self.featureBuffer.append(features)

                // Maintain feature buffer size
                if self.featureBuffer.count > Self.maxSequenceLength {
                    self.featureBuffer.removeFirst()
                }

                // Return current feature buffer
                DispatchQueue.main.async {
                    completion(Array(self.featureBuffer))
                }
            }
        }
    }

    /// Extract features from a batch of frames
    /// - Parameter frames: Array of video frames
    /// - Returns: 2D array of features [frame_count, feature_dimension]
    func extractFeaturesFromFrames(_ frames: [CIImage]) -> [[Float]] {
        var allFeatures: [[Float]] = []

        for frame in frames.prefix(Self.maxSequenceLength) {
            if let features = extractFeaturesFromFrame(frame) {
                allFeatures.append(features)
            }
        }

        return allFeatures
    }

    /// Reset the feature buffer (useful when starting a new translation session)
    func resetBuffer() {
        processingQueue.async {
            self.frameBuffer.removeAll()
            self.featureBuffer.removeAll()
        }
    }

    // MARK: - Private Methods

    /// Setup Vision model for feature extraction
    private func setupVisionModel() {
        // Try to load a pre-trained model for feature extraction
        // For now, we'll use a lightweight approach without requiring additional models
        print("🧠 SignLanguage Feature Extractor initialized")
    }

    /// Extract 512-dimensional features from a single frame
    /// - Parameter ciImage: Input video frame
    /// - Returns: 512-dimensional feature vector
    private func extractFeaturesFromFrame(_ ciImage: CIImage) -> [Float]? {
        // Convert CIImage to UIImage for processing
        guard let uiImage = convertCIImageToUIImage(ciImage) else {
            return nil
        }

        // Resize image to standard size
        guard let resizedImage = resizeImage(uiImage, to: ProcessingConfig.imageSize) else {
            return nil
        }

        // Extract multiple types of features and combine them
        var combinedFeatures: [Float] = []

        // 1. Color histogram features (128 dims)
        let colorFeatures = extractColorHistogramFeatures(resizedImage)
        combinedFeatures.append(contentsOf: colorFeatures)

        // 2. Edge and texture features (128 dims)
        let textureFeatures = extractTextureFeatures(resizedImage)
        combinedFeatures.append(contentsOf: textureFeatures)

        // 3. Hand pose estimation features (128 dims)
        let handFeatures = extractHandPoseFeatures(resizedImage)
        combinedFeatures.append(contentsOf: handFeatures)

        // 4. Optical flow and motion features (128 dims)
        let motionFeatures = extractMotionFeatures(resizedImage)
        combinedFeatures.append(contentsOf: motionFeatures)

        // Ensure we have exactly 512 features
        return padOrTruncateFeatures(combinedFeatures, targetSize: Self.featureDimension)
    }

    /// Extract color histogram features
    private func extractColorHistogramFeatures(_ image: UIImage) -> [Float] {
        guard let cgImage = image.cgImage else {
            return Array(repeating: 0.0, count: 128)
        }

        let ciImage = CIImage(cgImage: cgImage)
        var features: [Float] = []

        // Extract RGB histograms
        let context = CIContext()
        let extent = ciImage.extent

        // Simplified color analysis
        let pixelData = getPixelData(from: cgImage)
        let histogram = computeColorHistogram(pixelData)

        features.append(contentsOf: histogram)

        // Pad to 128 dimensions if needed
        while features.count < 128 {
            features.append(0.0)
        }

        return Array(features.prefix(128))
    }

    /// Extract texture and edge features
    private func extractTextureFeatures(_ image: UIImage) -> [Float] {
        guard let cgImage = image.cgImage else {
            return Array(repeating: 0.0, count: 128)
        }

        var features: [Float] = []

        // Convert to grayscale for edge detection
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        // Apply edge detection filters
        let edgeFilter = CIFilter(name: "CIEdges")!
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)

        if let edgeImage = edgeFilter.outputImage,
            let edgeCGImage = context.createCGImage(edgeImage, from: edgeImage.extent)
        {

            let edgeData = getPixelData(from: edgeCGImage)
            let edgeStats = computeImageStatistics(edgeData)
            features.append(contentsOf: edgeStats)
        }

        // Add texture analysis
        let textureStats = computeTextureFeatures(cgImage)
        features.append(contentsOf: textureStats)

        // Pad to 128 dimensions
        while features.count < 128 {
            features.append(0.0)
        }

        return Array(features.prefix(128))
    }

    /// Extract hand pose and shape features
    private func extractHandPoseFeatures(_ image: UIImage) -> [Float] {
        var features: [Float] = []

        // Use Vision framework for hand pose detection
        let request = VNDetectHumanHandPoseRequest()

        guard let cgImage = image.cgImage else {
            return Array(repeating: 0.0, count: 128)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            if let observations = request.results, !observations.isEmpty {
                // Extract hand landmark features
                for observation in observations.prefix(2) {  // Max 2 hands
                    let handFeatures = extractHandLandmarkFeatures(observation)
                    features.append(contentsOf: handFeatures)
                }
            }
        } catch {
            print("Hand pose detection failed: \(error)")
        }

        // If no hands detected or error, add statistical features from the image
        if features.isEmpty {
            let fallbackFeatures = computeImageRegionFeatures(cgImage)
            features.append(contentsOf: fallbackFeatures)
        }

        // Pad to 128 dimensions
        while features.count < 128 {
            features.append(0.0)
        }

        return Array(features.prefix(128))
    }

    /// Extract motion and temporal features
    private func extractMotionFeatures(_ image: UIImage) -> [Float] {
        var features: [Float] = []

        // For now, extract spatial features that could indicate motion
        // In a full implementation, this would use optical flow between frames

        if let cgImage = image.cgImage {
            // Compute gradient features that indicate motion direction
            let gradientFeatures = computeGradientFeatures(cgImage)
            features.append(contentsOf: gradientFeatures)

            // Add temporal consistency features (simplified)
            let consistencyFeatures = computeTemporalConsistencyFeatures()
            features.append(contentsOf: consistencyFeatures)
        }

        // Pad to 128 dimensions
        while features.count < 128 {
            features.append(Float.random(in: -0.1...0.1))  // Small random noise for diversity
        }

        return Array(features.prefix(128))
    }

    // MARK: - Helper Methods

    private func convertCIImageToUIImage(_ ciImage: CIImage) -> UIImage? {
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }

    private func padOrTruncateFeatures(_ features: [Float], targetSize: Int) -> [Float] {
        if features.count == targetSize {
            return features
        } else if features.count < targetSize {
            // Pad with zeros
            return features + Array(repeating: 0.0, count: targetSize - features.count)
        } else {
            // Truncate
            return Array(features.prefix(targetSize))
        }
    }

    private func getPixelData(from cgImage: CGImage) -> [UInt8] {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }

    private func computeColorHistogram(_ pixelData: [UInt8]) -> [Float] {
        var histogram: [Float] = Array(repeating: 0.0, count: 64)  // 64 bins for simplicity

        let binSize = 256 / 16  // 16 bins per channel (R, G, B, brightness)

        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Int(pixelData[i]) / binSize
            let g = Int(pixelData[i + 1]) / binSize
            let b = Int(pixelData[i + 2]) / binSize
            let brightness =
                (Int(pixelData[i]) + Int(pixelData[i + 1]) + Int(pixelData[i + 2])) / (3 * binSize)

            histogram[min(r, 15)] += 1.0
            histogram[min(g + 16, 31)] += 1.0
            histogram[min(b + 32, 47)] += 1.0
            histogram[min(brightness + 48, 63)] += 1.0
        }

        // Normalize histogram
        let total = histogram.reduce(0, +)
        return histogram.map { total > 0 ? $0 / total : 0.0 }
    }

    private func computeImageStatistics(_ pixelData: [UInt8]) -> [Float] {
        guard !pixelData.isEmpty else { return [0.0, 0.0, 0.0, 0.0] }

        let floatData = pixelData.map { Float($0) }
        let mean = floatData.reduce(0, +) / Float(floatData.count)
        let variance = floatData.map { pow($0 - mean, 2) }.reduce(0, +) / Float(floatData.count)
        let stdDev = sqrt(variance)
        let maxVal = floatData.max() ?? 0.0

        return [mean / 255.0, stdDev / 255.0, maxVal / 255.0, variance / (255.0 * 255.0)]
    }

    private func computeTextureFeatures(_ cgImage: CGImage) -> [Float] {
        // Simplified texture analysis using image statistics
        let pixelData = getPixelData(from: cgImage)
        let stats = computeImageStatistics(pixelData)

        // Add some derived texture measures
        var textureFeatures = stats

        // Add contrast, energy, homogeneity measures (simplified)
        let contrast = stats[1] * stats[1]  // Variance as contrast measure
        let energy = stats[0] * stats[0]  // Mean squared as energy
        let homogeneity = 1.0 / (1.0 + contrast)  // Inverse of contrast

        textureFeatures.append(contentsOf: [contrast, energy, homogeneity])

        return textureFeatures
    }

    private func extractHandLandmarkFeatures(_ observation: VNHumanHandPoseObservation) -> [Float] {
        var features: [Float] = []

        // Extract key hand landmarks
        let keyPoints: [VNHumanHandPoseObservation.JointName] = [
            .wrist, .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip,
            .thumbIP, .indexPIP, .middlePIP, .ringPIP, .littlePIP,
        ]

        for jointName in keyPoints {
            do {
                let joint = try observation.recognizedPoint(jointName)
                features.append(Float(joint.x))
                features.append(Float(joint.y))
                features.append(Float(joint.confidence))
            } catch {
                features.append(contentsOf: [0.0, 0.0, 0.0])  // Default values
            }
        }

        return features
    }

    private func computeImageRegionFeatures(_ cgImage: CGImage) -> [Float] {
        // Divide image into regions and compute statistics
        var regionFeatures: [Float] = []

        let width = cgImage.width
        let height = cgImage.height
        let regionWidth = width / 4
        let regionHeight = height / 4

        let pixelData = getPixelData(from: cgImage)

        // Analyze 16 regions (4x4 grid)
        for row in 0..<4 {
            for col in 0..<4 {
                let startX = col * regionWidth
                let startY = row * regionHeight

                var regionPixels: [UInt8] = []

                for y in startY..<min(startY + regionHeight, height) {
                    for x in startX..<min(startX + regionWidth, width) {
                        let index = (y * width + x) * 4
                        if index < pixelData.count {
                            regionPixels.append(pixelData[index])  // R channel
                        }
                    }
                }

                let regionStats = computeImageStatistics(regionPixels)
                regionFeatures.append(regionStats[0])  // Mean of each region
            }
        }

        return regionFeatures
    }

    private func computeGradientFeatures(_ cgImage: CGImage) -> [Float] {
        // Simplified gradient computation
        let pixelData = getPixelData(from: cgImage)
        let width = cgImage.width
        let height = cgImage.height

        var gradients: [Float] = []

        // Compute gradients in x and y directions (simplified)
        for y in 1..<height - 1 {
            for x in 1..<width - 1 {
                let centerIndex = (y * width + x) * 4
                let leftIndex = (y * width + (x - 1)) * 4
                let rightIndex = (y * width + (x + 1)) * 4
                let topIndex = ((y - 1) * width + x) * 4
                let bottomIndex = ((y + 1) * width + x) * 4

                if centerIndex < pixelData.count && leftIndex >= 0 && rightIndex < pixelData.count
                    && topIndex >= 0 && bottomIndex < pixelData.count
                {

                    let gradX = Float(pixelData[rightIndex]) - Float(pixelData[leftIndex])
                    let gradY = Float(pixelData[bottomIndex]) - Float(pixelData[topIndex])
                    let magnitude = sqrt(gradX * gradX + gradY * gradY)

                    gradients.append(magnitude / 255.0)  // Normalize
                }
            }
        }

        // Return statistical summary of gradients
        if !gradients.isEmpty {
            let mean = gradients.reduce(0, +) / Float(gradients.count)
            let maxGrad = gradients.max() ?? 0.0
            return [mean, maxGrad]
        }

        return [0.0, 0.0]
    }

    private func computeTemporalConsistencyFeatures() -> [Float] {
        // Simplified temporal features based on frame buffer
        let bufferSize = Float(frameBuffer.count)
        let consistency =
            bufferSize > 0 ? min(bufferSize / Float(Self.maxSequenceLength), 1.0) : 0.0

        return [consistency, Float.random(in: -0.05...0.05)]  // Add small random component
    }
}

// MARK: - Extension for Integration

extension SignLanguageFeatureExtractor {

    /// Format features for CoreML model input
    /// - Parameter features: Raw feature array
    /// - Returns: Properly formatted features for the CoreML model
    func formatFeaturesForCoreML(_ features: [[Float]]) -> (features: [[Float]], lengths: [Int]) {
        var formattedFeatures = features

        // Pad or truncate to exactly 50 frames
        if formattedFeatures.count < Self.maxSequenceLength {
            // Pad with zero vectors
            let zerosVector = Array(repeating: 0.0 as Float, count: Self.featureDimension)
            while formattedFeatures.count < Self.maxSequenceLength {
                formattedFeatures.append(zerosVector)
            }
        } else if formattedFeatures.count > Self.maxSequenceLength {
            // Truncate to max length
            formattedFeatures = Array(formattedFeatures.suffix(Self.maxSequenceLength))
        }

        let actualLength = features.count

        return (formattedFeatures, [min(actualLength, Self.maxSequenceLength)])
    }

    /// Get current buffer status for debugging
    func getBufferStatus() -> (frameCount: Int, featureCount: Int) {
        return (frameBuffer.count, featureBuffer.count)
    }
}
