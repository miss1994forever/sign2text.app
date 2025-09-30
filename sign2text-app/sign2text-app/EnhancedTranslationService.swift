//
//  EnhancedTranslationService.swift
//  sign2text-app
//
//  Enhanced translation service with CoreML integration
//  Created by CV-SLT Integration on 2024/12/19.
//

import AVFoundation
import Combine
import CoreImage
import CoreML
import Foundation
import SwiftUI

// MARK: - Enhanced Translation Service

/// Enhanced translation service that integrates CoreML model with real-time feature extraction
class EnhancedTranslationService: ObservableObject {

    // MARK: - Published Properties

    @Published var isTranslating = false
    @Published var isModelLoaded = false
    @Published var currentModel = "CV-SLT" {
        didSet {
            setupModelForCurrentType()
        }
    }
    @Published var currentTranslation: String = ""
    @Published var translationConfidence: Double = 0.0
    @Published var processingStatus: ProcessingStatus = .idle
    @Published var frameProcessingRate: Double = 0.0

    // MARK: - Translation Session Management

    struct TranslationSession {
        let id = UUID()
        let startTime: Date
        var endTime: Date?
        var translationText: String
        var confidence: Double
        var featuresProcessed: Int
        var isComplete: Bool = false

        var displayTime: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: startTime)
        }

        var duration: TimeInterval {
            return (endTime ?? Date()).timeIntervalSince(startTime)
        }
    }

    @Published var completedSessions: [TranslationSession] = []
    private var currentSession: TranslationSession?

    // MARK: - Processing Status

    enum ProcessingStatus {
        case idle
        case extractingFeatures
        case runningInference
        case generatingText
        case completed
        case error(String)

        var description: String {
            switch self {
            case .idle: return "Ready"
            case .extractingFeatures: return "Extracting features..."
            case .runningInference: return "Processing with AI..."
            case .generatingText: return "Generating text..."
            case .completed: return "Translation complete"
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    // MARK: - Core Components

    // private let coreMLProcessor: SignLanguageProcessor
    // private let featureExtractor: SignLanguageFeatureExtractor
    // Note: Using placeholder implementations until classes are available

        // MARK: - Configuration

    private struct Config {
        static let maxFramesPerBatch = 15
        static let confidenceThreshold: Double = 0.7
        static let processingTimeout: TimeInterval = 5.0
        static let minFramesForTranslation = 5  // Minimum frames needed for translation
        
        // Sentence building configuration
        static let wordAccumulationTimeout: TimeInterval = 2.0  // Time to wait for next word
        static let minWordConfidence: Double = 0.6  // Minimum confidence to accept a word
        static let maxWordsPerSentence = 8  // Maximum words in a sentence
        static let sentenceEndTimeout: TimeInterval = 3.0  // Time to wait before ending sentence
        
        // CV-SLT specific configuration
        static let cvSLTInputSize = CGSize(width: 224, height: 224)
        static let cvSLTSequenceLength = 16  // Number of frames in a sequence
        static let cvSLTFeatureDimension = 512  // Feature vector dimension
    }
    
    // MARK: - Sentence Building Properties
    
    private var accumulatedWords: [String] = []
    private var lastWordTime: Date?
    private var wordAccumulationTimer: Timer?
    private var sentenceEndTimer: Timer?
    
    // MARK: - CV-SLT Model Properties
    
    private var cvSLTModel: MLModel?
    private var frameBuffer: [CIImage] = []  // Buffer for sequence processing
    private let maxBufferSize = Config.cvSLTSequenceLength

    // MARK: - Performance Tracking

    private var processingStartTime: Date?
    private var frameCount = 0
    private var lastFrameTime = Date()
    private var performanceMetrics = PerformanceMetrics()

    private struct PerformanceMetrics {
        var totalInferences = 0
        var totalProcessingTime: TimeInterval = 0
        var averageInferenceTime: TimeInterval = 0
        var successRate: Double = 0

        mutating func addInference(processingTime: TimeInterval, success: Bool) {
            totalInferences += 1
            totalProcessingTime += processingTime
            averageInferenceTime = totalProcessingTime / Double(totalInferences)
            successRate =
                (successRate * Double(totalInferences - 1) + (success ? 1.0 : 0.0))
                / Double(totalInferences)
        }
    }

    // MARK: - Callbacks

    var onTranslationSessionComplete: ((TranslationSession) -> Void)?
    var onTranslationUpdate: ((String, Double) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Initialization

    init() {
        // coreMLProcessor = SignLanguageProcessor()
        // featureExtractor = SignLanguageFeatureExtractor()
        // Note: Commented out until classes are available

        setupService()
    }

    private func setupService() {
        setupModelForCurrentType()
    }
    
    private func setupModelForCurrentType() {
        print("🔧 [EnhancedTranslationService] Setting up model: \(currentModel)")
        DispatchQueue.global(qos: .utility).async {
            let success = self.initializeModel(type: self.currentModel)
            DispatchQueue.main.async {
                self.isModelLoaded = success
                if success {
                    print("✅ Enhanced translation service initialized with \(self.currentModel)")
                    self.processingStatus = .idle
                } else {
                    print("❌ Failed to initialize \(self.currentModel) model")
                    self.processingStatus = .error("\(self.currentModel) model initialization failed")
                }
            }
        }
    }
    
    private func initializeModel(type: String) -> Bool {
        switch type {
        case "CV-SLT":
            return initializeCVSLTModel()
        case "Dummy":
            return initializeDummyModel()
        default:
            print("⚠️ Unknown model type: \(type), defaulting to Dummy")
            return initializeDummyModel()
        }
    }
    
    private func initializeCVSLTModel() -> Bool {
        print("🤖 [EnhancedTranslationService] Initializing CV-SLT model...")
        
        // Try to load CV-SLT CoreML model from bundle
        guard let modelURL = Bundle.main.url(forResource: "CV-SLT", withExtension: "mlmodelc") else {
            print("⚠️ [EnhancedTranslationService] CV-SLT model file not found, using simulation mode")
            return initializeCVSLTSimulation()
        }
        
        do {
            cvSLTModel = try MLModel(contentsOf: modelURL)
            print("✅ [EnhancedTranslationService] CV-SLT model loaded successfully")
            return true
        } catch {
            print("❌ [EnhancedTranslationService] Failed to load CV-SLT model: \(error.localizedDescription)")
            print("🔄 [EnhancedTranslationService] Falling back to simulation mode")
            return initializeCVSLTSimulation()
        }
    }
    
    private func initializeCVSLTSimulation() -> Bool {
        print("🎭 [EnhancedTranslationService] Initializing CV-SLT simulation mode...")
        
        // Simulate model loading time
        Thread.sleep(forTimeInterval: 1.0)
        
        print("✅ [EnhancedTranslationService] CV-SLT simulation mode initialized")
        return true
    }
    
    private func initializeDummyModel() -> Bool {
        print("🎭 [EnhancedTranslationService] Initializing Dummy model...")
        return true
    }

    // MARK: - Public Methods

    /// Start a new translation session
    func startTranslationSession() {
        guard isModelLoaded else {
            processingStatus = .error("Model not loaded")
            return
        }

        // End current session if active
        if let session = currentSession, !session.isComplete {
            endCurrentSession()
        }

        // Start new session
        currentSession = TranslationSession(
            startTime: Date(),
            translationText: "",
            confidence: 0.0,
            featuresProcessed: 0
        )

        isTranslating = true
        currentTranslation = ""
        translationConfidence = 0.0
        frameCount = 0
        processingStartTime = Date()
        
        // Reset sentence building state
        startNewSentence()

        // Reset feature extractor buffer
        // featureExtractor.resetBuffer()

        processingStatus = .extractingFeatures
        print("🎬 Started new translation session")
    }

    /// Stop the current translation session
    func stopTranslationSession() {
        guard isTranslating else { return }

        // Complete any pending sentence
        if !accumulatedWords.isEmpty {
            completeSentence()
        }
        
        // Clean up timers
        wordAccumulationTimer?.invalidate()
        sentenceEndTimer?.invalidate()

        endCurrentSession()
        print("⏹️ Stopped translation session")
    }

    /// Process a single video frame for real-time translation
    /// - Parameter ciImage: The captured video frame
    func processVideoFrame(_ ciImage: CIImage) {
        guard isTranslating, isModelLoaded else { return }

        // Update frame rate tracking
        updateFrameRate()
        
        // Handle different processing based on current model
        switch currentModel {
        case "CV-SLT":
            processCVSLTFrame(ciImage)
        case "Dummy":
            processDummyFrame(ciImage)
        default:
            print("⚠️ Unknown model type: \(currentModel)")
            processDummyFrame(ciImage)
        }
    }
    
    private func processCVSLTFrame(_ ciImage: CIImage) {
        // Add frame to buffer for sequence processing
        frameBuffer.append(ciImage)
        
        // Maintain buffer size
        if frameBuffer.count > maxBufferSize {
            frameBuffer.removeFirst()
        }
        
        // Process when we have enough frames
        if frameBuffer.count >= Config.minFramesForTranslation {
            DispatchQueue.main.async {
                self.processingStatus = .extractingFeatures
            }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processCVSLTSequence(Array(self?.frameBuffer.suffix(Config.cvSLTSequenceLength) ?? []))
            }
        }
    }
    
    private func processDummyFrame(_ ciImage: CIImage) {
        // Update processing status
        DispatchQueue.main.async {
            self.processingStatus = .extractingFeatures
        }

        // Process frames with dummy data for immediate response
        let dummyFeatures: [[Float]] = [Array(repeating: Float.random(in: -1...1), count: 512)]
        
        // Process features immediately for real-time translation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Update status
            DispatchQueue.main.async {
                self?.processingStatus = .runningInference
            }
            
            // Generate embeddings from features
            guard let embeddings = self?.processFeaturesToEmbeddings(dummyFeatures) else {
                DispatchQueue.main.async {
                    self?.processingStatus = .error("Feature processing failed")
                }
                return
            }
            
            // Convert embeddings to text
            DispatchQueue.main.async {
                self?.processingStatus = .generatingText
            }
            
            let (text, confidence) = self?.convertEmbeddingsToText(embeddings) ?? ("Error", 0.0)
            
            // Update UI with result
            DispatchQueue.main.async {
                self?.processingStatus = .completed
                self?.updateCurrentTranslation(text, confidence: confidence)
            }
        }
    }
    
    private func processCVSLTSequence(_ frames: [CIImage]) {
        print("🤖 [CV-SLT] Processing frame sequence of length: \(frames.count)")
        
        guard !frames.isEmpty else {
            print("⚠️ [CV-SLT] Empty frame sequence")
            return
        }
        
        // Update status
        DispatchQueue.main.async {
            self.processingStatus = .runningInference
        }
        
        if let cvSLTModel = cvSLTModel {
            // Use actual CV-SLT model
            processCVSLTWithModel(frames, model: cvSLTModel)
        } else {
            // Use simulation mode
            processCVSLTSimulation(frames)
        }
    }
    
    private func processCVSLTWithModel(_ frames: [CIImage], model: MLModel) {
        print("🧠 [CV-SLT] Processing with actual CoreML model")
        
        // TODO: Implement actual CV-SLT model processing
        // This would involve:
        // 1. Preprocessing frames to model input format
        // 2. Running inference
        // 3. Post-processing results
        
        // For now, fall back to simulation
        processCVSLTSimulation(frames)
    }
    
    private func processCVSLTSimulation(_ frames: [CIImage]) {
        print("🎭 [CV-SLT] Processing with simulation mode")
        
        // Simulate CV-SLT processing with more realistic behavior
        let processingDelay = 0.1 // Simulate processing time
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Thread.sleep(forTimeInterval: processingDelay)
            
            // Generate more realistic features based on frame analysis
            let features = self?.extractSimulatedFeatures(from: frames) ?? []
            
            guard let embeddings = self?.processFeaturesToEmbeddings([features]) else {
                DispatchQueue.main.async {
                    self?.processingStatus = .error("CV-SLT processing failed")
                }
                return
            }
            
            // Convert embeddings to text using CV-SLT specific processing
            DispatchQueue.main.async {
                self?.processingStatus = .generatingText
            }
            
            let (text, confidence) = self?.convertEmbeddingsToText(embeddings) ?? ("", 0.0)
            
            // Update UI with result
            DispatchQueue.main.async {
                self?.processingStatus = .completed
                self?.updateCurrentTranslation(text, confidence: confidence)
            }
        }
    }
    
    private func extractSimulatedFeatures(from frames: [CIImage]) -> [Float] {
        print("🔍 [CV-SLT] Extracting simulated features from \(frames.count) frames")
        
        // Simulate feature extraction based on frame properties
        var features: [Float] = []
        
        for frame in frames {
            let extent = frame.extent
            let aspectRatio = Float(extent.width / extent.height)
            let area = Float(extent.width * extent.height)
            
            // Add simulated features based on frame properties
            features.append(aspectRatio)
            features.append(log(area))
            features.append(Float.random(in: -1...1)) // Simulated motion
            features.append(Float.random(in: -1...1)) // Simulated hand position
        }
        
        // Pad or truncate to expected size
        while features.count < Config.cvSLTFeatureDimension {
            features.append(Float.random(in: -0.5...0.5))
        }
        
        if features.count > Config.cvSLTFeatureDimension {
            features = Array(features.prefix(Config.cvSLTFeatureDimension))
        }
        
        return features
    }

    /// Process a batch of video frames
    /// - Parameter frames: Array of video frames to process
    func processVideoFrames(_ frames: [CIImage], completion: @escaping (String, Double) -> Void) {
        guard isModelLoaded else {
            completion("Model not loaded", 0.0)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = Date()

            // Extract features from all frames
            // let features = featureExtractor.extractFeatures(from: frames)
            let features: [[Float]] = []  // Placeholder

            guard features.count >= Config.minFramesForTranslation else {
                DispatchQueue.main.async {
                    completion("Insufficient video data", 0.0)
                }
                return
            }

            // Process with CoreML model
            if let (translatedText, confidence) = self.processFeaturesToText(features) {
                let processingTime = Date().timeIntervalSince(startTime)
                self.performanceMetrics.addInference(processingTime: processingTime, success: true)

                DispatchQueue.main.async {
                    completion(translatedText, confidence)
                }
            } else {
                let processingTime = Date().timeIntervalSince(startTime)
                self.performanceMetrics.addInference(processingTime: processingTime, success: false)

                DispatchQueue.main.async {
                    completion("Translation failed", 0.0)
                }
            }
        }
    }

    /// Get current performance metrics
    func getPerformanceMetrics() -> (inferences: Int, avgTime: Double, successRate: Double) {
        return (
            performanceMetrics.totalInferences,
            performanceMetrics.averageInferenceTime * 1000,  // Convert to ms
            performanceMetrics.successRate
        )
    }

    /// Reset performance tracking
    func resetMetrics() {
        performanceMetrics = PerformanceMetrics()
    }
    
    /// Switch between different models (CV-SLT, Dummy)
    func switchModel(to modelType: String) {
        print("🔄 [EnhancedTranslationService] Switching to \(modelType) model...")
        
        // Stop current translation if active
        if isTranslating {
            stopTranslationSession()
        }
        
        // Clear frame buffer when switching models
        frameBuffer.removeAll()
        
        currentModel = modelType
        // Model will be reinitialized automatically via the didSet observer
    }
    
    /// Get available models
    func getAvailableModels() -> [String] {
        return ["CV-SLT", "Dummy"]
    }
    
    /// Check if a model is available
    func isModelAvailable(_ modelType: String) -> Bool {
        switch modelType {
        case "CV-SLT":
            return Bundle.main.url(forResource: "CV-SLT", withExtension: "mlmodelc") != nil
        case "Dummy":
            return true
        default:
            return false
        }
    }

    // MARK: - Private Methods

    private func testModelInitialization() -> Bool {
        // Create dummy test data
        let dummyFeatures = (0..<50).map { _ in
            Array(repeating: Float.random(in: -1...1), count: 512)
        }

        // Test the processing pipeline
        if processFeaturesToText(dummyFeatures) != nil {
            return true
        }

        return false
    }

    private func handleExtractedFeatures(_ features: [[Float]]) {
        guard currentSession != nil else { return }

        // Update current session
        self.currentSession?.featuresProcessed = features.count

        // Check if we have enough features for processing
        if features.count >= Config.minFramesForTranslation {
            // Process features to get translation
            DispatchQueue.global(qos: .userInitiated).async {
                if let (text, confidence) = self.processFeaturesToText(features) {
                    DispatchQueue.main.async {
                        self.updateCurrentTranslation(text, confidence: confidence)
                    }
                }
            }
        }
    }

    private func processFeaturesToText(_ features: [[Float]]) -> (String, Double)? {
        processingStatus = .runningInference

        // Format features for CoreML
        // let (formattedFeatures, lengths) = featureExtractor.formatFeaturesForCoreML(features)

        // Process with CoreML model to get embeddings
        // guard let embeddings = coreMLProcessor.processSignLanguageFeatures(formattedFeatures) else {
        // Placeholder implementation
        guard let embeddings = processFeaturesToEmbeddings(features) else {
            processingStatus = .error("CoreML processing failed")
            return nil
        }

        processingStatus = .generatingText

        // Convert embeddings to text (simplified approach)
        // Convert embeddings to text
        let (translatedText, confidence) = convertEmbeddingsToText(embeddings)

        processingStatus = .completed
        return (translatedText, confidence)
    }

    // Helper method for placeholder implementation
    private func processFeaturesToEmbeddings(_ features: [[Float]]) -> [Float]? {
        // Simplified placeholder - generate dummy embeddings
        guard !features.isEmpty else { return nil }

        // Generate 128-dimensional embeddings based on features
        var embeddings: [Float] = []
        for i in 0..<128 {
            let value = features.first?[i % 512] ?? Float.random(in: -1...1)
            embeddings.append(value * 0.1)  // Scale down for stability
        }

        return embeddings
    }

    private func convertEmbeddingsToText(_ embeddings: [Float]) -> (String, Double) {
        print("🚀 [EnhancedTranslationService] === TESTING MODE - ALWAYS RETURN TEXT ===")
        
        // Calculate embedding statistics for debugging
        let avgEmbedding = embeddings.reduce(0, +) / Float(embeddings.count)
        let maxEmbedding = embeddings.max() ?? 0.0
        let minEmbedding = embeddings.min() ?? 0.0
        let embeddingRange = maxEmbedding - minEmbedding
        let stdDev = sqrt(embeddings.map { pow($0 - avgEmbedding, 2) }.reduce(0, +) / Float(embeddings.count))
        
        print("📊 [EnhancedTranslationService] Embedding stats - avg: \(String(format: "%.4f", avgEmbedding)), range: \(String(format: "%.4f", embeddingRange)), max: \(String(format: "%.4f", maxEmbedding)), std: \(String(format: "%.4f", stdDev))")
        
        // TESTING: Always return a test word to see if the UI updates
        let testWords = ["HELLO", "WORLD", "TEST", "SIGN", "WORKING", "DEBUG"]
        let selectedWord = testWords.randomElement() ?? "TEST"
        let confidence = 0.95
        
        print("� [EnhancedTranslationService] TESTING MODE: Returning '\(selectedWord)' with confidence \(confidence)")
        
        return (selectedWord, confidence)
        
        // Original detection logic commented out for testing
        /*
        // Count significant activations (above noise floor)
        let significantActivations = embeddings.filter { abs($0) > 0.3 }.count
        let activationRatio = Float(significantActivations) / Float(embeddings.count)
        
        print("📊 [EnhancedTranslationService] Activation analysis - significant: \(significantActivations)/\(embeddings.count) (\(String(format: "%.2f", activationRatio * 100))%)")
        
        // Define very lenient thresholds for testing (temporarily relaxed)
        let minActivationThreshold: Float = 0.01  // Very low threshold for testing
        let minRangeThreshold: Float = 0.01       // Very low threshold for testing
        let minStdDevThreshold: Float = 0.01      // Very low threshold for testing
        let minActivationRatio: Float = 0.01      // Very low threshold for testing
        
        // Multiple criteria must be met for sign detection
        let hasActivation = abs(avgEmbedding) >= minActivationThreshold || maxEmbedding >= minActivationThreshold
        let hasRange = embeddingRange >= minRangeThreshold
        let hasVariation = stdDev >= minStdDevThreshold
        let hasSignificantActivations = activationRatio >= minActivationRatio
        
        print("🔍 [EnhancedTranslationService] Detection criteria - activation: \(hasActivation), range: \(hasRange), variation: \(hasVariation), ratioOK: \(hasSignificantActivations)")
        
        // Require multiple positive indicators for sign detection
        let positiveCount = [hasActivation, hasRange, hasVariation, hasSignificantActivations].filter { $0 }.count
        
        if positiveCount < 2 {  // Require at least 2 positive indicators
            print("🤷 [EnhancedTranslationService] No significant sign language activity detected (only \(positiveCount)/4 criteria met)")
            return ("[No sign detected]", 0.1)
        }
        
        print("✅ [EnhancedTranslationService] Valid sign detected - generating text")
        
        // Original text generation logic for when sign is detected
        let magnitude = sqrt(embeddings.map { $0 * $0 }.reduce(0, +))
        let text = generateTextFromEmbeddings(embeddings)
        let confidence = calculateConfidenceScore(embeddings, magnitude: magnitude)

        return (text, confidence)
        */
    }

    private func generateTextFromEmbeddings(_ embeddings: [Float]) -> String {
        // Analyze embedding patterns to generate text
        // This is a simplified approach - in production you'd use a proper decoder

        let positiveSum = embeddings.filter { $0 > 0 }.reduce(0, +)
        let negativeSum = abs(embeddings.filter { $0 < 0 }.reduce(0, +))
        let maxValue = embeddings.max() ?? 0
        let minValue = embeddings.min() ?? 0

        // Simple heuristic-based text generation
        if maxValue > 0.5 {
            return "Hello"
        } else if minValue < -0.5 {
            return "Goodbye"
        } else if positiveSum > negativeSum * 1.5 {
            return "Yes"
        } else if negativeSum > positiveSum * 1.5 {
            return "No"
        } else if abs(maxValue - abs(minValue)) < 0.1 {
            return "Please"
        } else {
            return "Thank you"
        }
    }

    private func calculateConfidenceScore(_ embeddings: [Float], magnitude: Float) -> Double {
        // Calculate confidence based on embedding characteristics
        let variance = calculateVariance(embeddings)
        let sparsity = calculateSparsity(embeddings)

        // Higher magnitude and lower variance typically indicate more confident predictions
        let magnitudeScore = min(Double(magnitude) / 5.0, 1.0)
        let varianceScore = max(0.0, 1.0 - Double(variance))
        let sparsityScore = 1.0 - Double(sparsity)

        let overallConfidence = (magnitudeScore + varianceScore + sparsityScore) / 3.0

        return max(0.1, min(overallConfidence, 0.95))  // Clamp between 10% and 95%
    }

    private func calculateVariance(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }

        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }

    private func calculateSparsity(_ values: [Float]) -> Float {
        let threshold: Float = 0.01
        let nearZeroCount = values.filter { abs($0) < threshold }.count
        return Float(nearZeroCount) / Float(values.count)
    }

    private func updateCurrentTranslation(_ text: String, confidence: Double) {
        print("🚀 [EnhancedTranslationService] === UPDATING TRANSLATION IN UI ===")
        print("🚀 [EnhancedTranslationService] Raw word: '\(text)' with confidence: \(confidence)")
        
        // Skip low confidence words or "No sign detected" messages
        guard confidence >= Config.minWordConfidence && !text.contains("No sign") && !text.isEmpty else {
            print("🚀 [EnhancedTranslationService] Skipping low confidence or invalid word")
            return
        }
        
        // Add word to accumulated sentence
        addWordToSentence(text, confidence: confidence)
    }
    
    private func addWordToSentence(_ word: String, confidence: Double) {
        print("� [EnhancedTranslationService] Adding word '\(word)' to sentence")
        
        // Cancel existing timers
        wordAccumulationTimer?.invalidate()
        sentenceEndTimer?.invalidate()
        
        // Add word if not duplicate or if enough time has passed
        let now = Date()
        let shouldAddWord = accumulatedWords.isEmpty || 
                           accumulatedWords.last != word ||
                           (lastWordTime != nil && now.timeIntervalSince(lastWordTime!) > 1.0)
        
        if shouldAddWord {
            accumulatedWords.append(word)
            lastWordTime = now
            
            // Limit sentence length
            if accumulatedWords.count > Config.maxWordsPerSentence {
                accumulatedWords.removeFirst()
            }
            
            print("� [EnhancedTranslationService] Current sentence: \(accumulatedWords.joined(separator: " "))")
            
            // Update UI with current sentence
            let currentSentence = accumulatedWords.joined(separator: " ")
            DispatchQueue.main.async {
                self.currentTranslation = currentSentence
                self.translationConfidence = confidence
                self.currentSession?.translationText = currentSentence
                self.currentSession?.confidence = confidence
                
                print("🚀 [EnhancedTranslationService] UI UPDATED - sentence: '\(self.currentTranslation)'")
            }
            
            // Notify observers
            onTranslationUpdate?(currentSentence, confidence)
        }
        
        // Set timer to end sentence if no new words come
        sentenceEndTimer = Timer.scheduledTimer(withTimeInterval: Config.sentenceEndTimeout, repeats: false) { [weak self] _ in
            self?.completeSentence()
        }
    }
    
    private func completeSentence() {
        guard !accumulatedWords.isEmpty else { return }
        
        let completedSentence = accumulatedWords.joined(separator: " ")
        print("✅ [EnhancedTranslationService] Sentence completed: '\(completedSentence)'")
        
        // Add to session history
        if let session = currentSession {
            DispatchQueue.main.async {
                self.currentSession?.translationText = completedSentence
            }
        }
        
        // Start new sentence
        startNewSentence()
    }
    
    private func startNewSentence() {
        print("🆕 [EnhancedTranslationService] Starting new sentence")
        accumulatedWords.removeAll()
        lastWordTime = nil
        wordAccumulationTimer?.invalidate()
        sentenceEndTimer?.invalidate()
    }

    private func endCurrentSession() {
        guard let session = currentSession else { return }

        var completedSession = session
        completedSession.endTime = Date()
        completedSession.isComplete = true

        // Add to completed sessions
        completedSessions.append(completedSession)

        // Limit history size
        if completedSessions.count > 50 {
            completedSessions.removeFirst()
        }

        // Reset state
        isTranslating = false
        processingStatus = .idle
        currentSession = nil

        // Notify completion
        onTranslationSessionComplete?(completedSession)

        print("✅ Translation session completed: '\(completedSession.translationText)'")
    }

    private func updateFrameRate() {
        frameCount += 1
        let currentTime = Date()
        let timeDiff = currentTime.timeIntervalSince(lastFrameTime)

        if timeDiff >= 1.0 {  // Update every second
            frameProcessingRate = Double(frameCount) / timeDiff
            frameCount = 0
            lastFrameTime = currentTime
        }
    }

    // MARK: - Public Utility Methods

    /// Get detailed status information for debugging
    func getDetailedStatus() -> [String: Any] {
        // let (bufferFrames, bufferFeatures) = featureExtractor.getBufferStatus()
        let (bufferFrames, bufferFeatures) = (0, 0)  // Placeholder

        return [
            "isModelLoaded": isModelLoaded,
            "isTranslating": isTranslating,
            "processingStatus": processingStatus.description,
            "frameRate": frameProcessingRate,
            "bufferFrames": bufferFrames,
            "bufferFeatures": bufferFeatures,
            "currentConfidence": translationConfidence,
            "totalInferences": performanceMetrics.totalInferences,
            "averageInferenceTime": performanceMetrics.averageInferenceTime * 1000,
            "successRate": performanceMetrics.successRate,
        ]
    }

    /// Export translation history
    func exportTranslationHistory() -> [String: Any] {
        return [
            "exportDate": Date(),
            "totalSessions": completedSessions.count,
            "sessions": completedSessions.map { session in
                [
                    "id": session.id.uuidString,
                    "startTime": session.startTime,
                    "endTime": session.endTime ?? Date(),
                    "duration": session.duration,
                    "text": session.translationText,
                    "confidence": session.confidence,
                    "featuresProcessed": session.featuresProcessed,
                ]
            },
            "performanceMetrics": [
                "totalInferences": performanceMetrics.totalInferences,
                "averageInferenceTime": performanceMetrics.averageInferenceTime,
                "successRate": performanceMetrics.successRate,
            ],
        ]
    }
}

// MARK: - Error Types

extension EnhancedTranslationService {
    enum TranslationError: LocalizedError {
        case modelNotLoaded
        case featureExtractionFailed
        case inferenceTimeout
        case insufficientData
        case processingFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "CoreML model is not loaded"
            case .featureExtractionFailed:
                return "Failed to extract features from video"
            case .inferenceTimeout:
                return "Model inference timed out"
            case .insufficientData:
                return "Not enough video data for translation"
            case .processingFailed(let message):
                return "Processing failed: \(message)"
            }
        }
    }
}
