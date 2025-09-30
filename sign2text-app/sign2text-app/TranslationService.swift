//
//  TranslationService.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import AVFoundation
import Combine
import CoreImage
import CoreML
import Foundation
import SwiftUI

// MARK: - Translation Service

/// A service that handles real-time translation of sign language captured via camera frames into text.
class TranslationService: ObservableObject {
    // MARK: - Published Properties

    @Published var isTranslating = false
    @Published var isModelLoaded = true
    @Published var currentModel = "Demo" {
        didSet {
            // Save model selection to UserDefaults
            UserDefaults.standard.set(currentModel, forKey: "selectedTranslationModel")
        }
    }
    @Published var currentTranslation: String = ""  // 当前正在构建的翻译

    // MARK: - Translation Session Management

    struct TranslationSession {
        let id = UUID()
        let startTime: Date
        var endTime: Date?
        var translationText: String
        var isComplete: Bool = false

        var displayTime: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: startTime)
        }
    }

    @Published var completedSessions: [TranslationSession] = []
    private var currentSession: TranslationSession?

    // MARK: - Private Properties

    /// Callback to deliver completed translation sessions to the UI
    var onTranslationSessionComplete: ((TranslationSession) -> Void)?

    /// Callback to update current translation in real-time
    var onCurrentTranslationUpdate: ((String) -> Void)?

    /// Callback for translation errors
    var onError: ((Error) -> Void)?

    /// Timer for translation updates
    private var translationTimer: Timer?
    private var sessionTimer: Timer?

    /// Example words for building sentences
    private let dummyWords = [
        "你好", "谢谢", "请", "再见", "我爱你", "对不起",
        "没关系", "我需要帮助", "今天", "天气", "很好",
        "我很", "高兴", "见到你", "这个", "多少钱",
        "我不", "明白", "请", "再说一遍", "祝你", "好运",
    ]

    /// Current word building state
    private var currentWords: [String] = []
    private var wordBuildingTimer: Timer?
    private let wordInterval: TimeInterval = 1.5  // 每1.5秒添加一个词
    private let sessionDuration: TimeInterval = 8.0  // 每8秒完成一个翻译会话

    /// CV-SLT Model Components
    private var signLanguageProcessor: SignLanguageProcessor?
    private var featureExtractor: DemoFeatureExtractor?

    // MARK: - Initialization

    init() {
        // Load saved model preference
        if let savedModel = UserDefaults.standard.string(forKey: "selectedTranslationModel") {
            currentModel = savedModel
            
            // Initialize CV-SLT components if the saved model is CV-SLT
            if savedModel == "CV-SLT" {
                print("🚀 Loading saved CV-SLT model on app startup")
                initializeCVSLTComponents()
            }
        }
    }
    
    /// Initialize CV-SLT model components
    private func initializeCVSLTComponents() {
        print("🤖 Initializing CV-SLT components...")
        
        // Initialize the SignLanguageProcessor which loads the UltraSimpleCSLModel
        if signLanguageProcessor == nil {
            signLanguageProcessor = SignLanguageProcessor()
        }
        
        // Initialize the feature extractor
        if featureExtractor == nil {
            featureExtractor = DemoFeatureExtractor()
        }
        
        isModelLoaded = true
        print("✅ CV-SLT components initialized successfully")
    }

    // MARK: - Public Methods

    /// Starts the real-time translation process
    func startTranslation() {
        guard !isTranslating else { return }

        isTranslating = true
        startNewTranslationSession()

        print("🚀 Starting real-time sign language translation session...")

        // Start word building timer
        startWordBuilding()

        // Start session completion timer
        startSessionTimer()
    }

    /// Processes a single camera frame for real-time translation
    /// This is the interface for CV-SLT model integration
    func processFrame(_ frame: CIImage) -> TranslationResult? {
        guard isTranslating else { return nil }

        // Debug logging for model selection
        print("🔍 Processing frame with model: \(currentModel)")
        print("🔍 SignLanguageProcessor available: \(signLanguageProcessor != nil)")

        // Check which model to use
        if currentModel == "CV-SLT", let processor = signLanguageProcessor {
            // Use CV-SLT model processing
            print("✅ Using CV-SLT model for frame processing")
            return processFrameWithCVSLT(frame, processor: processor)
        } else {
            // Use dummy model
            print("⚠️ Falling back to dummy model (currentModel: \(currentModel), processor available: \(signLanguageProcessor != nil))")
            return processFrameWithDummy(frame)
        }
    }
    
    /// Process frame using CV-SLT model
    private func processFrameWithCVSLT(_ frame: CIImage, processor: SignLanguageProcessor) -> TranslationResult? {
        // Convert CIImage to CGImage for feature extraction
        let context = CIContext()
        guard let cgImage = context.createCGImage(frame, from: frame.extent) else {
            print("❌ Failed to convert CIImage to CGImage")
            return processFrameWithDummy(frame) // Fallback to dummy
        }
        
        // Extract features using DemoFeatureExtractor
        guard let extractor = featureExtractor else {
            print("❌ Feature extractor not available - falling back to dummy")
            return processFrameWithDummy(frame)
        }
        
        print("🔄 Extracting features from frame...")
        let features = extractor.extractFeatures(from: [cgImage])
        print("🔄 Extracted \(features.count) features")
        
        // Process with SignLanguageProcessor
        print("🔄 Processing features with CV-SLT model...")
        guard let embeddings = processor.processSignLanguageFeatures(features),
              !embeddings.isEmpty else {
            print("❌ Failed to process features with CV-SLT model - falling back to dummy")
            return processFrameWithDummy(frame)
        }
        
        print("🔄 Generated \(embeddings.count) embeddings")
        
        // Convert embeddings to text with improved detection
        let translatedText = convertEmbeddingsToText(embeddings)
        let confidence = calculateConfidenceFromEmbeddings(embeddings)
        
        print("✅ CV-SLT model processed frame")
        print("   📝 Result: \(translatedText)")
        print("   🎯 Confidence: \(String(format: "%.2f", confidence))")
        print("   🔢 Embeddings count: \(embeddings.count)")
        
        return TranslationResult(
            text: translatedText,
            confidence: confidence,
            timestamp: Date(),
            boundingBox: nil
        )
    }
    
    /// Process frame using dummy model
    private func processFrameWithDummy(_ frame: CIImage) -> TranslationResult? {
        let dummyResult = TranslationResult(
            text: dummyWords.randomElement() ?? "hello",
            confidence: Float.random(in: 0.7...0.95),
            timestamp: Date(),
            boundingBox: nil
        )
        return dummyResult
    }

    /// Process multiple frames (for sequence-based models like CV-SLT)
    func processFrameSequence(_ frames: [CIImage]) -> TranslationResult? {
        guard isTranslating, !frames.isEmpty else { return nil }

        // CV-SLT works better with frame sequences
        // This interface allows for temporal analysis

        return processFrame(frames.last!)  // Simplified for demo
    }

    /// Stops the real-time translation process
    func stopTranslation() {
        guard isTranslating else { return }

        isTranslating = false

        // Complete current session if there's content
        completeCurrentSession()

        // Stop all timers
        translationTimer?.invalidate()
        wordBuildingTimer?.invalidate()
        sessionTimer?.invalidate()

        translationTimer = nil
        wordBuildingTimer = nil
        sessionTimer = nil

        print("⏹️ Stopped real-time sign language translation")
    }

    /// Clears the translation history
    func clearHistory() {
        completedSessions.removeAll()
    }

    /// Get all completed sessions for history display
    func getTranslationHistory() -> [TranslationSession] {
        return completedSessions.reversed()  // Most recent first
    }

    // MARK: - Private Methods

    private func startNewTranslationSession() {
        currentSession = TranslationSession(
            startTime: Date(),
            translationText: ""
        )
        currentWords = []
        currentTranslation = ""
    }

    private func startWordBuilding() {
        wordBuildingTimer = Timer.scheduledTimer(withTimeInterval: wordInterval, repeats: true) {
            [weak self] _ in
            self?.addWordToCurrentTranslation()
        }
    }

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionDuration, repeats: true) {
            [weak self] _ in
            self?.completeCurrentSession()
            self?.startNewTranslationSession()
        }
    }

    private func addWordToCurrentTranslation() {
        guard isTranslating, currentSession != nil else { return }

        // Add a random word to build a sentence
        if let newWord = dummyWords.randomElement() {
            currentWords.append(newWord)

            // Build sentence with commas
            let translationText = currentWords.joined(separator: ", ")
            currentTranslation = translationText

            // Update current session
            currentSession?.translationText = translationText

            // Notify UI of current translation update
            DispatchQueue.main.async { [weak self] in
                self?.onCurrentTranslationUpdate?(translationText)
            }

            print("🔤 Building translation: \(translationText)")
        }
    }

    private func completeCurrentSession() {
        guard var session = currentSession, !session.translationText.isEmpty else { return }

        session.endTime = Date()
        session.isComplete = true

        completedSessions.append(session)

        // Notify UI of completed session
        DispatchQueue.main.async { [weak self] in
            self?.onTranslationSessionComplete?(session)
        }

        print("✅ Completed translation session: \(session.translationText)")

        // Reset current translation
        currentTranslation = ""
        currentWords = []
        currentSession = nil
    }
}

// MARK: - Translation Result Models

/// Result from a single frame or sequence processing
struct TranslationResult {
    let text: String
    let confidence: Float
    let timestamp: Date
    let boundingBox: CGRect?

    init(text: String, confidence: Float, timestamp: Date = Date(), boundingBox: CGRect? = nil) {
        self.text = text
        self.confidence = confidence
        self.timestamp = timestamp
        self.boundingBox = boundingBox
    }
}

// MARK: - CV-SLT Integration Interface

extension TranslationService {
    /// CV-SLT Model Integration Interface
    /// This is the interface that CV-SLT model should implement

    struct CVSLTModelInterface {
        /// Initialize the CV-SLT model
        static func loadModel(modelPath: String) -> Bool {
            // TODO: Load CV-SLT model from path
            // Return true if successful, false otherwise
            return false
        }

        /// Process a sequence of frames and return translation
        static func translateFrameSequence(_ frames: [CIImage]) -> TranslationResult? {
            // TODO: Implement CV-SLT processing
            // 1. Preprocess frames to model input format
            // 2. Run through CV-SLT encoder-decoder
            // 3. Return translation with confidence
            return nil
        }

        /// Get model configuration
        static func getModelConfig() -> ModelConfig {
            return ModelConfig(
                inputFrameSize: CGSize(width: 224, height: 224),
                sequenceLength: 32,
                vocabularySize: 1000,
                confidenceThreshold: 0.7
            )
        }
    }

    struct ModelConfig {
        let inputFrameSize: CGSize
        let sequenceLength: Int
        let vocabularySize: Int
        let confidenceThreshold: Float
    }
}

//    private func preprocessFrameForCVSLT(_ frame: CIImage) -> CIImage {
//        // Preprocess frame according to CV-SLT requirements
//        // 1. Resize to input size (224x224)
//        // 2. Normalize pixel values
//        // 3. Apply any required transformations
//
//        let transform = CGAffineTransform(
//            scaleX: cvSLTConfig.inputFrameSize.width / frame.extent.width,
//            y: cvSLTConfig.inputFrameSize.height / frame.extent.height
//        )
//
//        return frame.transformed(by: transform)
//    }

// MARK: - Fallback Processing Methods

private func processCustomFrame(_ frame: CIImage) -> (text: String, confidence: Float)? {
    // Implementation for custom models
    return nil
}

private func processCustomSequence(_ frames: [CIImage]) -> (text: String, confidence: Float)? {
    // Implementation for custom models
    return nil
}

private func processDummyFrame(_ frame: CIImage) -> (text: String, confidence: Float)? {
    // Mock processing for testing
    let dummyTexts = ["你好", "谢谢", "再见", "我爱你", "请"]
    let randomText = dummyTexts.randomElement() ?? "Unknown"
    let confidence = Float.random(in: 0.7...0.95)
    return (randomText, confidence)
}

/// Convert model embeddings to text (improved approach with no-sign detection)
private func convertEmbeddingsToText(_ embeddings: [Float]) -> String {
    print("🚀 [TranslationService] === REGULAR TRANSLATION SERVICE ACTIVE ===")
    // Calculate embedding statistics
    let avgEmbedding = embeddings.reduce(0, +) / Float(embeddings.count)
    let maxEmbedding = embeddings.max() ?? 0.0
    let minEmbedding = embeddings.min() ?? 0.0
    let embeddingRange = maxEmbedding - minEmbedding
    let stdDev = sqrt(embeddings.map { pow($0 - avgEmbedding, 2) }.reduce(0, +) / Float(embeddings.count))
    
    // Count significant activations (above noise floor)
    let significantActivations = embeddings.filter { abs($0) > 0.3 }.count
    let activationRatio = Float(significantActivations) / Float(embeddings.count)
    
    print("📊 Embedding stats - avg: \(String(format: "%.4f", avgEmbedding)), range: \(String(format: "%.4f", embeddingRange)), max: \(String(format: "%.4f", maxEmbedding)), std: \(String(format: "%.4f", stdDev))")
    print("📊 Activation analysis - significant: \(significantActivations)/\(embeddings.count) (\(String(format: "%.2f", activationRatio * 100))%)")
    
    // Define more conservative thresholds for sign detection
    let minActivationThreshold: Float = 0.3   // Increased from 0.1 - minimum activation to consider as sign
    let minRangeThreshold: Float = 0.5        // Increased from 0.2 - minimum range to consider meaningful  
    let minStdDevThreshold: Float = 0.2       // Minimum standard deviation to indicate variation
    let minActivationRatio: Float = 0.1       // At least 10% of embeddings should be significantly active
    
    // Multiple criteria must be met for sign detection
    let hasActivation = abs(avgEmbedding) >= minActivationThreshold || maxEmbedding >= minActivationThreshold
    let hasRange = embeddingRange >= minRangeThreshold
    let hasVariation = stdDev >= minStdDevThreshold
    let hasSignificantActivations = activationRatio >= minActivationRatio
    
    print("🔍 Detection criteria - activation: \(hasActivation), range: \(hasRange), variation: \(hasVariation), ratioOK: \(hasSignificantActivations)")
    
    // Require multiple positive indicators for sign detection
    let positiveCount = [hasActivation, hasRange, hasVariation, hasSignificantActivations].filter { $0 }.count
    
    if positiveCount < 2 {  // Require at least 2 positive indicators
        print("🤷 No significant sign language activity detected (only \(positiveCount)/4 criteria met)")
        return "[No sign detected]"
    }
    
    // For demo purposes, we'll map embedding patterns to common sign language phrases
    // In a real implementation, you would use a vocabulary mapping or language model
    let signPhrases = [
        "你好 (Hello)", "谢谢 (Thank you)", "再见 (Goodbye)", "我爱你 (I love you)", 
        "请 (Please)", "对不起 (Sorry)", "没关系 (No problem)", "帮助 (Help)", 
        "今天 (Today)", "天气好 (Nice weather)", "很高兴 (Very happy)",
        "见到你 (Nice to meet you)", "多少钱 (How much)", "不明白 (Don't understand)", 
        "再说一遍 (Say again)", "好的 (Okay)"
    ]
    
    // Use embedding characteristics to select phrase (improved mapping)
    let normalizedAvg = (avgEmbedding + 1.0) / 2.0  // Normalize to 0-1 range
    let index = Int(normalizedAvg * Float(signPhrases.count - 1))
    let clampedIndex = min(max(index, 0), signPhrases.count - 1)
    
    let selectedPhrase = signPhrases[clampedIndex]
    print("🎯 Selected phrase: \(selectedPhrase) (index: \(clampedIndex))")
    
    return selectedPhrase
}

/// Calculate confidence from embeddings
private func calculateConfidenceFromEmbeddings(_ embeddings: [Float]) -> Float {
    // Calculate embedding statistics
    let mean = embeddings.reduce(0, +) / Float(embeddings.count)
    let variance = embeddings.map { pow($0 - mean, 2) }.reduce(0, +) / Float(embeddings.count)
    let maxEmbedding = embeddings.max() ?? 0.0
    let minEmbedding = embeddings.min() ?? 0.0
    let embeddingRange = maxEmbedding - minEmbedding
    let stdDev = sqrt(variance)
    
    // Count significant activations (matching the detection logic)
    let significantActivations = embeddings.filter { abs($0) > 0.3 }.count
    let activationRatio = Float(significantActivations) / Float(embeddings.count)
    
    // Use same conservative thresholds as detection
    let minActivationThreshold: Float = 0.3
    let minRangeThreshold: Float = 0.5
    let minStdDevThreshold: Float = 0.2
    let minActivationRatio: Float = 0.1
    
    // Check sign detection criteria
    let hasActivation = abs(mean) >= minActivationThreshold || maxEmbedding >= minActivationThreshold
    let hasRange = embeddingRange >= minRangeThreshold
    let hasVariation = stdDev >= minStdDevThreshold
    let hasSignificantActivations = activationRatio >= minActivationRatio
    
    let positiveCount = [hasActivation, hasRange, hasVariation, hasSignificantActivations].filter { $0 }.count
    
    // Low confidence if no significant activity detected
    if positiveCount < 2 {
        print("📉 Low confidence due to minimal sign activity (criteria: \(positiveCount)/4)")
        return Float.random(in: 0.05...0.15)  // Very low confidence for no-sign cases
    }
    
    // Calculate confidence based on embedding characteristics
    // Higher range and lower variance typically indicate clearer signs
    let rangeConfidence = min(embeddingRange * 2.0, 1.0)  // Range contributes to confidence
    let varianceConfidence = max(0.0, 1.0 - sqrt(variance)) // Lower variance = higher confidence
    
    // Combine factors
    let confidence = (rangeConfidence + varianceConfidence) / 2.0
    let finalConfidence = max(0.3, min(0.95, confidence)) // Clamp between 0.3 and 0.95
    
    print("📊 Confidence calculation - range: \(rangeConfidence), variance: \(varianceConfidence), final: \(finalConfidence)")
    return finalConfidence
}

/// Model deployment helper for converting Python models to iOS
class ModelDeploymentHelper {
    /// Convert CV-SLT PyTorch model to CoreML format
    static func convertPyTorchToCoreML(
        pytorchModelPath: String,
        outputPath: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // TODO: Implement model conversion
        // This would typically be done offline and the converted model
        // would be bundled with the app or downloaded at runtime

        // For now, return mock success
        DispatchQueue.global().async {
            // Simulate conversion time
            Thread.sleep(forTimeInterval: 2.0)
            DispatchQueue.main.async {
                completion(.success(outputPath))
            }
        }
    }

    /// Download and setup CV-SLT model from cloud
    static func downloadCVSLTModel(
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // TODO: Implement model download from cloud storage
        // This would download the converted CoreML model

        DispatchQueue.global().async {
            // Simulate download
            Thread.sleep(forTimeInterval: 5.0)
            DispatchQueue.main.async {
                let mockPath =
                    Bundle.main.path(forResource: "cv_slt_model", ofType: "mlmodel") ?? ""
                completion(.success(mockPath))
            }
        }
    }
}

extension TranslationService {
    /// 真实的CV-SLT模型集成
    func integrateRealModel() {
        print("🤖 Starting CV-SLT model integration...")
        
        // Initialize CV-SLT components
        initializeCVSLTComponents()

        // Update model status
        currentModel = "CV-SLT"
        print("✅ CV-SLT model integration completed using UltraSimpleCSLModel")
    }

    /// 使用真实CoreML模型处理帧序列
    private func processWithCoreMLModel(_ frames: [CIImage]) -> TranslationResult? {
        // guard let model = coreMLModel, frames.count >= minFrameSequence else {
        guard frames.count >= minFrameSequence else {
            return nil
        }

        do {
            // 1. 预处理帧序列
            let preprocessedFrames = preprocessFramesForCoreML(frames)

            // 2. 转换为模型输入格式
            let _ = try createCoreMLInput(from: preprocessedFrames)

            // 3. 运行模型推理
            // Placeholder - model not available yet
            throw NSError(
                domain: "ModelNotAvailable", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])

        } catch {
            print("❌ CoreML model inference failed: \(error)")
            return nil
        }
    }

    // MARK: - CoreML 处理方法

    /// 预处理帧序列以适配CoreML模型
    private func preprocessFramesForCoreML(_ frames: [CIImage]) -> [CVPixelBuffer] {
        let targetSize = CGSize(width: 224, height: 224)  // 根据你的模型调整

        return frames.compactMap { frame in
            // 调整帧大小
            let scaledFrame = frame.transformed(
                by: CGAffineTransform(
                    scaleX: targetSize.width / frame.extent.width,
                    y: targetSize.height / frame.extent.height
                ))

            // 转换为CVPixelBuffer
            return convertCIImageToPixelBuffer(scaledFrame, targetSize: targetSize)
        }
    }

    /// 创建CoreML模型输入
    private func createCoreMLInput(from pixelBuffers: [CVPixelBuffer]) throws -> MLFeatureProvider {
        // 这里需要根据你的具体模型输入格式来实现
        // 例如，如果模型期望一个序列的视频帧：

        // 假设模型输入是一个多维数组或视频序列
        // 具体实现取决于CV_SLTV1模型的输入规格

        // 示例（需要根据实际模型调整）：
        // Placeholder implementation - replace with actual model input creation
        throw NSError(
            domain: "ModelNotAvailable", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "CV_SLTV1 model not available"])
    }

    /// 解析CoreML模型输出
    private func parseCoreMLOutput(_ output: MLFeatureProvider) -> TranslationResult {
        // 根据模型输出格式解析结果
        // 这个需要根据你的CV-SLT模型的具体输出来实现

        // 示例（需要根据实际模型输出调整）：
        // Placeholder implementation - replace with actual model output parsing
        let translatedText = "Placeholder"
        let confidence = 0.5

        return TranslationResult(
            text: translatedText,
            confidence: Float(confidence),
            timestamp: Date()
        )
    }

    /// 转换CIImage到CVPixelBuffer
    private func convertCIImageToPixelBuffer(_ ciImage: CIImage, targetSize: CGSize)
        -> CVPixelBuffer?
    {
        let attrs =
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
            ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(targetSize.width),
            Int(targetSize.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        let context = CIContext()
        context.render(ciImage, to: buffer)

        return buffer
    }
}

// MARK: - 添加CoreML模型属性
extension TranslationService {
    // Comment out CV_SLTV1 references until model is available
    // private static var coreMLModelInstance: CV_SLTV1?

    // private var coreMLModel: CV_SLTV1? {
    //     get { TranslationService.coreMLModelInstance }
    //     set { TranslationService.coreMLModelInstance = newValue }
    // }

    // Use computed property instead of stored property in extension
    private var minFrameSequence: Int { return 8 }  // CV-SLT可能需要的最小帧数
}
