//
//  DemoFeatureExtractor.swift
//  Super simple feature extractor for immediate testing
//

import AVFoundation
import CoreGraphics
import SwiftUI

class DemoFeatureExtractor: ObservableObject {

    /// Extract features from video frames (WORKING IMPLEMENTATION)
    func extractFeatures(from frames: [CGImage]) -> [[Float]] {
        print("🎯 Extracting features from \(frames.count) frames")

        // Sample frames to max 50
        let maxFrames = 50
        let sampledFrames = sampleFrames(frames, targetCount: maxFrames)

        var allFeatures: [[Float]] = []

        for (index, frame) in sampledFrames.enumerated() {
            let features = extractSingleFrameFeatures(frame)
            allFeatures.append(features)

            if index % 10 == 0 {
                print("📊 Processed \(index + 1)/\(sampledFrames.count) frames")
            }
        }

        // Pad to exactly 50 frames
        while allFeatures.count < maxFrames {
            allFeatures.append(Array(repeating: 0.0, count: 512))
        }

        print("✅ Feature extraction complete: \(allFeatures.count) × 512")
        return allFeatures
    }

    /// Extract 512 features from a single frame
    private func extractSingleFrameFeatures(_ image: CGImage) -> [Float] {
        var features: [Float] = []

        // 1. Basic image properties (4 features)
        features.append(contentsOf: getBasicImageFeatures(image))

        // 2. Color features (128 features)
        features.append(contentsOf: getColorFeatures(image))

        // 3. Spatial features (128 features)
        features.append(contentsOf: getSpatialFeatures(image))

        // 4. Simple visual patterns (252 features to reach 512 total)
        features.append(contentsOf: getPatternFeatures(image))

        // Ensure exactly 512 features
        return Array(features.prefix(512))
    }
}

// MARK: - Feature Extraction Implementation

extension DemoFeatureExtractor {

    private func getBasicImageFeatures(_ image: CGImage) -> [Float] {
        let width = Float(image.width)
        let height = Float(image.height)
        let aspectRatio = width / height
        let area = width * height

        return [
            width / 1000.0,  // Normalized width
            height / 1000.0,  // Normalized height
            aspectRatio,  // Aspect ratio
            area / 1000000.0,  // Normalized area
        ]
    }

    private func getColorFeatures(_ image: CGImage) -> [Float] {
        let cgImage = image

        // Sample pixels from image
        let samplePoints = [
            (0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75),  // Corners
            (0.5, 0.5),  // Center
            (0.5, 0.25), (0.5, 0.75), (0.25, 0.5), (0.75, 0.5),  // Mid-points
        ]

        var colorFeatures: [Float] = []

        for (x, y) in samplePoints {
            let pixelX = Int(Float(cgImage.width) * Float(x))
            let pixelY = Int(Float(cgImage.height) * Float(y))

            if let (r, g, b) = getPixelColor(cgImage, x: pixelX, y: pixelY) {
                colorFeatures.append(contentsOf: [r, g, b])

                // Add derived color features
                let brightness = (r + g + b) / 3.0
                let saturation = max(r, g, b) - min(r, g, b)
                colorFeatures.append(contentsOf: [brightness, saturation])
            } else {
                colorFeatures.append(contentsOf: [0.5, 0.5, 0.5, 0.5, 0.0])
            }
        }

        // Add overall image color statistics
        let (avgR, avgG, avgB) = calculateAverageColors(cgImage)
        colorFeatures.append(contentsOf: [avgR, avgG, avgB])

        // Pad to 128 features
        while colorFeatures.count < 128 {
            colorFeatures.append(Float.random(in: 0...0.1))
        }

        return Array(colorFeatures.prefix(128))
    }

    private func getSpatialFeatures(_ image: CGImage) -> [Float] {
        let cgImage = image

        var spatialFeatures: [Float] = []

        // Grid-based features (8×8 grid = 64 cells)
        let gridSize = 8
        let cellWidth = cgImage.width / gridSize
        let cellHeight = cgImage.height / gridSize

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let centerX = col * cellWidth + cellWidth / 2
                let centerY = row * cellHeight + cellHeight / 2

                if let (r, g, b) = getPixelColor(cgImage, x: centerX, y: centerY) {
                    // Use brightness as the spatial feature for this cell
                    let brightness = (r + g + b) / 3.0
                    spatialFeatures.append(brightness)
                } else {
                    spatialFeatures.append(0.0)
                }
            }
        }

        // Add position-based features
        spatialFeatures.append(contentsOf: Array(repeating: Float.random(in: 0...0.1), count: 64))

        return Array(spatialFeatures.prefix(128))
    }

    private func getPatternFeatures(_ image: CGImage) -> [Float] {
        // Generate pattern-like features (this is simplified)
        // In a real implementation, you'd detect actual visual patterns

        var patternFeatures: [Float] = []

        // Simulate edge patterns
        patternFeatures.append(contentsOf: Array(repeating: Float.random(in: 0...0.2), count: 64))

        // Simulate texture patterns
        patternFeatures.append(contentsOf: Array(repeating: Float.random(in: 0...0.3), count: 64))

        // Simulate motion patterns (for video this would be temporal)
        patternFeatures.append(contentsOf: Array(repeating: Float.random(in: 0...0.1), count: 64))

        // Random additional features to reach target count
        patternFeatures.append(contentsOf: Array(repeating: Float.random(in: 0...0.05), count: 60))

        return Array(patternFeatures.prefix(252))
    }
}

// MARK: - Utility Functions

extension DemoFeatureExtractor {

    private func sampleFrames(_ frames: [CGImage], targetCount: Int) -> [CGImage] {
        guard frames.count > targetCount else { return frames }

        let step = Double(frames.count) / Double(targetCount)
        var sampledFrames: [CGImage] = []

        for i in 0..<targetCount {
            let index = Int(Double(i) * step)
            let clampedIndex = min(index, frames.count - 1)
            sampledFrames.append(frames[clampedIndex])
        }

        return sampledFrames
    }

    private func getPixelColor(_ cgImage: CGImage, x: Int, y: Int) -> (Float, Float, Float)? {
        guard x >= 0 && x < cgImage.width && y >= 0 && y < cgImage.height,
            let dataProvider = cgImage.dataProvider,
            let data = dataProvider.data,
            let bytes = CFDataGetBytePtr(data)
        else {
            return nil
        }

        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel

        let r = Float(bytes[offset]) / 255.0
        let g = Float(bytes[offset + 1]) / 255.0
        let b = Float(bytes[offset + 2]) / 255.0

        return (r, g, b)
    }

    private func calculateAverageColors(_ cgImage: CGImage) -> (Float, Float, Float) {
        guard let dataProvider = cgImage.dataProvider,
            let data = dataProvider.data,
            let bytes = CFDataGetBytePtr(data)
        else {
            return (0.5, 0.5, 0.5)
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow

        var rSum: Int = 0
        var gSum: Int = 0
        var bSum: Int = 0
        var pixelCount = 0

        // Sample every 10th pixel for performance
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                rSum += Int(bytes[offset])
                gSum += Int(bytes[offset + 1])
                bSum += Int(bytes[offset + 2])
                pixelCount += 1
            }
        }

        return (
            Float(rSum) / Float(pixelCount) / 255.0,
            Float(gSum) / Float(pixelCount) / 255.0,
            Float(bSum) / Float(pixelCount) / 255.0
        )
    }
}

// MARK: - Extension for Video Frame Extraction

extension DemoFeatureExtractor {

    /// Extract frames from a video URL
    func extractFramesFromVideo(_ videoURL: URL, maxFrames: Int = 30) async -> [CGImage]? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        guard let duration = try? await asset.load(.duration) else {
            print("❌ Could not get video duration")
            return nil
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        let frameInterval = durationSeconds / Double(maxFrames)

        var frames: [CGImage] = []

        for i in 0..<maxFrames {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                frames.append(cgImage)
            } catch {
                print("⚠️ Could not extract frame at \(Double(i) * frameInterval)s: \(error)")
            }
        }

        print("✅ Extracted \(frames.count) frames from video")
        return frames.isEmpty ? nil : frames
    }
}
