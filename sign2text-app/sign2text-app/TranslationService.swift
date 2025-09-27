//
//  TranslationService.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import AVFoundation
import Combine
import CoreImage
import Foundation
import SwiftUI

// MARK: - Translation Service

/// A service that handles real-time translation of sign language captured via camera frames into text.
class TranslationService: ObservableObject {
    // MARK: - Published Properties

    @Published var isTranslating = false
    @Published var isModelLoaded = true
    @Published var currentModel = "Demo"
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
        "我不", "明白", "请", "再说一遍", "祝你", "好运"
    ]

    /// Current word building state
    private var currentWords: [String] = []
    private var wordBuildingTimer: Timer?
    private let wordInterval: TimeInterval = 1.5  // 每1.5秒添加一个词
    private let sessionDuration: TimeInterval = 8.0  // 每8秒完成一个翻译会话

    // MARK: - Initialization

    init() {
        // Initialize with default settings
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

        // CV-SLT Integration Interface:
        // 1. Input: CIImage frame from camera
        // 2. Processing: Extract features, run through model
        // 3. Output: TranslationResult with text and confidence
        
        // For now, return dummy data
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
        
        return processFrame(frames.last!) // Simplified for demo
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
        return completedSessions.reversed() // Most recent first
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
        wordBuildingTimer = Timer.scheduledTimer(withTimeInterval: wordInterval, repeats: true) { [weak self] _ in
            self?.addWordToCurrentTranslation()
        }
    }
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionDuration, repeats: true) { [weak self] _ in
            self?.completeCurrentSession()
            self?.startNewTranslationSession()
        }
    }
    
    private func addWordToCurrentTranslation() {
        guard isTranslating, let session = currentSession else { return }
        
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
                let mockPath = Bundle.main.path(forResource: "cv_slt_model", ofType: "mlmodel") ?? ""
                completion(.success(mockPath))
            }
        }
    }
}
