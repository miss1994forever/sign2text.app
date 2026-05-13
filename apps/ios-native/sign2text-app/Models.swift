//
//  Models.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import CoreImage
import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Sign Language Recognition Models

enum RecognitionBackendPreset: String, CaseIterable, Identifiable, Codable {
    case cslDaily = "csl-daily"
    case phoenix = "phoenix"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cslDaily:
            return "CSL-Daily"
        case .phoenix:
            return "PHOENIX"
        }
    }

    var subtitle: String {
        switch self {
        case .cslDaily:
            return "800-word CSL-Daily recognition"
        case .phoenix:
            return "PHOENIX weather-domain recognition"
        }
    }

    var backendURLStorageKey: String {
        "sign2text.backendURL.\(rawValue)"
    }
}

/// Represents a recognized sign language gesture with confidence score
struct SignLanguageRecognition {
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

/// Represents a sign language word in the dictionary
struct SignLanguageWord: Identifiable, Codable {
    var id = UUID()
    let word: String
    let description: String?
    let category: SignLanguageCategory
    let mediaFiles: [MediaFile]  // Videos and images for this word
    let dateAdded: Date
    let addedBy: String?
    var isCloudSynced: Bool = false
    var cloudURL: String?

    init(
        word: String, description: String? = nil, category: SignLanguageCategory = .general,
        mediaFiles: [MediaFile] = [], addedBy: String? = nil
    ) {
        self.word = word
        self.description = description
        self.category = category
        self.mediaFiles = mediaFiles
        self.dateAdded = Date()
        self.addedBy = addedBy
    }
    
    // Custom coding keys to handle all properties
    enum CodingKeys: String, CodingKey {
        case id, word, description, category, mediaFiles, dateAdded, addedBy, isCloudSynced, cloudURL
    }
}

/// Represents a media file (video or image) for a sign language word
struct MediaFile: Identifiable, Codable {
    var id = UUID()
    let fileName: String
    let type: MediaType
    let localPath: String?
    let cloudURL: String?
    let fileSize: Int64
    let duration: TimeInterval? // For videos
    let thumbnail: String? // Thumbnail path
    let dateCreated: Date
    var isCloudSynced: Bool = false

    enum MediaType: String, Codable {
        case video = "video"
        case image = "image"
        
        var icon: String {
            switch self {
            case .video: return "video.fill"
            case .image: return "photo.fill"
            }
        }
    }
}

/// Categories for organizing sign language words
enum SignLanguageCategory: String, CaseIterable, Codable {
    case general = "General"
    case greetings = "Greetings"
    case emotions = "Emotions"
    case family = "Family"
    case food = "Food"
    case colors = "Colors"
    case numbers = "Numbers"
    case alphabet = "Alphabet"
    case actions = "Actions"
    case places = "Places"
    case time = "Time"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .general: return "hand.raised"
        case .greetings: return "hand.wave"
        case .emotions: return "heart"
        case .family: return "person.3"
        case .food: return "fork.knife"
        case .colors: return "paintpalette"
        case .numbers: return "123.rectangle"
        case .alphabet: return "textformat.abc"
        case .actions: return "figure.walk"
        case .places: return "location"
        case .time: return "clock"
        case .custom: return "star"
        }
    }
}

/// Translation session for tracking a complete interaction
struct TranslationSession: Identifiable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    var recognitions: [SignLanguageRecognition]
    var isActive: Bool

    init(startTime: Date = Date()) {
        self.startTime = startTime
        self.endTime = nil
        self.recognitions = []
        self.isActive = true
    }

    mutating func addRecognition(_ recognition: SignLanguageRecognition) {
        recognitions.append(recognition)
    }

    mutating func endSession() {
        endTime = Date()
        isActive = false
    }

    var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }

    var fullText: String {
        return recognitions.map { $0.text }.joined(separator: " ")
    }
}

/// Camera frame data for processing
struct CameraFrame {
    let image: CIImage
    let timestamp: Date
    let orientation: Int

    init(image: CIImage, timestamp: Date = Date(), orientation: Int = 0) {
        self.image = image
        self.timestamp = timestamp
        self.orientation = orientation
    }
}

/// AI Model configuration for sign language recognition
struct ModelConfiguration {
    let modelName: String
    let modelPath: String?
    let confidenceThreshold: Float
    let maxDetections: Int
    let inputSize: CGSize
    let isRealtime: Bool

    init(
        modelName: String,
        modelPath: String? = nil,
        confidenceThreshold: Float = 0.7,
        maxDetections: Int = 5,
        inputSize: CGSize = CGSize(width: 224, height: 224),
        isRealtime: Bool = true
    ) {
        self.modelName = modelName
        self.modelPath = modelPath
        self.confidenceThreshold = confidenceThreshold
        self.maxDetections = maxDetections
        self.inputSize = inputSize
        self.isRealtime = isRealtime
    }

    /// Default configuration for CV-SLT model
    static let cvSLTModel = ModelConfiguration(
        modelName: "CV-SLT",
        modelPath: Bundle.main.path(forResource: "cv_slt_model", ofType: "mlmodelc"),
        confidenceThreshold: 0.75,
        maxDetections: 3,
        inputSize: CGSize(width: 256, height: 256),
        isRealtime: true
    )

    /// Dummy model configuration for development
    static let dummyModel = ModelConfiguration(
        modelName: "Dummy",
        modelPath: nil,
        confidenceThreshold: 0.7,
        maxDetections: 1,
        inputSize: CGSize(width: 224, height: 224),
        isRealtime: true
    )
}

/// App settings and preferences
struct AppSettings {
    var selectedModelConfiguration: String
    var enableHapticFeedback: Bool
    var enableSoundFeedback: Bool
    var autoSaveTranslations: Bool
    var cameraPosition: CameraPosition
    var frameRate: Int
    var translationLanguage: String

    init() {
        self.selectedModelConfiguration = "Dummy"
        self.enableHapticFeedback = true
        self.enableSoundFeedback = false
        self.autoSaveTranslations = true
        self.cameraPosition = .front
        self.frameRate = 30
        self.translationLanguage = "zh-CN"
    }
}

/// Camera position enum
enum CameraPosition: String, CaseIterable {
    case front = "front"
    case back = "back"

    var displayName: String {
        switch self {
        case .front: return "Front Camera"
        case .back: return "Back Camera"
        }
    }
}

/// Translation history item
struct TranslationHistoryItem: Identifiable {
    var id = UUID()
    let originalText: String
    let translatedText: String
    let timestamp: Date
    let confidence: Float
    let sessionId: UUID?

    init(originalText: String, translatedText: String, confidence: Float, sessionId: UUID? = nil) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = Date()
        self.confidence = confidence
        self.sessionId = sessionId
    }
}

/// Error types for sign language processing
enum SignLanguageError: LocalizedError {
    case cameraNotAvailable
    case cameraPermissionDenied
    case modelLoadingFailed(String)
    case processingFailed(String)
    case invalidFrame
    case networkError(String)
    case storageError(String)

    var errorDescription: String? {
        switch self {
        case .cameraNotAvailable:
            return "Camera is not available on this device"
        case .cameraPermissionDenied:
            return "Camera permission is required for sign language recognition"
        case .modelLoadingFailed(let details):
            return "Failed to load AI model: \(details)"
        case .processingFailed(let details):
            return "Processing failed: \(details)"
        case .invalidFrame:
            return "Invalid camera frame received"
        case .networkError(let details):
            return "Network error: \(details)"
        case .storageError(let details):
            return "Storage error: \(details)"
        }
    }
}
