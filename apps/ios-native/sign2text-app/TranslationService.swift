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

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Translation Service

/// A service that handles real-time translation of sign language captured via camera frames into text.
class TranslationService: ObservableObject {
    // MARK: - Published Properties

    @Published var isTranslating = false
    @Published var isModelLoaded = false
    @Published var currentModel = "SLRT Backend"
    @Published var currentTranslation: String = ""
    @Published var backendURL: String = UserDefaults.standard.string(forKey: "sign2text.backendURL") ?? "http://127.0.0.1:6006"
    @Published var connectionStatus = "Disconnected"
    @Published var lastErrorMessage: String?
    @Published var latestSkeletonFrame: SkeletonOverlayFrame?
    
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

    private let ciContext = CIContext()
    private let stateQueue = DispatchQueue(label: "signscribe.translation.state")
    private let frameSubmissionInterval: TimeInterval = 0.2
    private let inferenceInterval: TimeInterval = 0.45
    private let inferenceEveryNFrames = 1
    private let jpegCompressionQuality: CGFloat = 0.55
    private let maxEncodedFrameDimension: CGFloat = 320

    private var backendSessionId: String?
    private var frameIndex = 0
    private var submittedFrameCount = 0
    private var isStartingSession = false
    private var isSendingFrame = false
    private var isInferring = false
    private var isStoppingSession = false
    private var lastSubmittedFrameAt = Date.distantPast
    private var lastInferenceAt = Date.distantPast

    // MARK: - Initialization

    init() {
        refreshBackendHealth()
    }

    // MARK: - Public Methods

    /// Starts the real-time translation process
    func startTranslation() {
        guard !isTranslating else { return }

        DispatchQueue.main.async {
            self.isTranslating = true
            self.isModelLoaded = false
            self.currentModel = "SLRT Backend"
            self.currentTranslation = ""
            self.latestSkeletonFrame = nil
            self.connectionStatus = "Connecting"
            self.lastErrorMessage = nil
        }
        resetRuntimeState()
        startNewTranslationSession()
        Task {
            await ensureBackendSession()
        }
    }

    /// Processes a single camera frame for real-time translation
    func processFrame(_ frame: CIImage) -> TranslationResult? {
        guard isTranslating else { return nil }
        let now = Date()
        guard let encodedFrame = encodeFrame(frame) else {
            publishError(SignLanguageError.processingFailed("Failed to encode camera frame"))
            return nil
        }

        guard let submission = reserveFrameSubmission(at: now) else { return nil }

        Task {
            await submitFrame(
                encodedFrame: encodedFrame,
                frameIndex: submission.frameIndex,
                timestampMs: submission.timestampMs
            )
        }

        return nil
    }
    
    /// Process multiple frames (for sequence-based models like CV-SLT)
    func processFrameSequence(_ frames: [CIImage]) -> TranslationResult? {
        guard isTranslating, !frames.isEmpty else { return nil }

        return processFrame(frames.last!) // Simplified for demo
    }

    /// Stops the real-time translation process
    func stopTranslation() {
        guard isTranslating else { return }

        DispatchQueue.main.async {
            self.isTranslating = false
            self.connectionStatus = "Stopping"
        }

        Task {
            await finishBackendSession()
        }
    }

    /// Clears the translation history
    func clearHistory() {
        DispatchQueue.main.async {
            self.completedSessions.removeAll()
            self.currentTranslation = ""
            self.latestSkeletonFrame = nil
        }
    }
    
    /// Get all completed sessions for history display
    func getTranslationHistory() -> [TranslationSession] {
        return completedSessions.reversed() // Most recent first
    }

    // MARK: - Private Methods
    
    func setBackendURL(_ newValue: String) {
        let normalized = normalizeBaseURL(newValue)
        DispatchQueue.main.async {
            self.backendURL = normalized
            if Self.looksLikeLoopbackURL(normalized) {
                self.lastErrorMessage = "127.0.0.1 only works on the Mac or simulator. For a physical iPhone, use your Mac's LAN IP, e.g. http://192.168.x.x:6006"
            }
        }
        UserDefaults.standard.set(normalized, forKey: "sign2text.backendURL")
    }

    func refreshBackendHealth() {
        Task {
            do {
                let health: BackendHealthResponse = try await sendRequest(path: "/api/v1/health", method: "GET")
                await MainActor.run {
                    self.isModelLoaded = health.modelLoaded
                    self.connectionStatus = health.status == "ok" ? "Backend reachable" : health.status
                    self.lastErrorMessage = nil
                }
            } catch {
                publishError(error)
                await MainActor.run {
                    self.connectionStatus = "Backend unavailable"
                }
            }
        }
    }

    var statusSummary: String {
        let errorSuffix = (lastErrorMessage?.isEmpty == false) ? " • \(lastErrorMessage!)" : ""
        return "\(connectionStatus) • Model: \(currentModel)\(errorSuffix)"
    }

    private func startNewTranslationSession() {
        currentSession = TranslationSession(
            startTime: Date(),
            translationText: ""
        )
        DispatchQueue.main.async {
            self.currentTranslation = ""
            self.latestSkeletonFrame = nil
        }
    }

    private func completeCurrentSession(with finalText: String? = nil) {
        guard var session = currentSession else { return }
        if let finalText, !finalText.isEmpty {
            session.translationText = finalText
        }
        guard !session.translationText.isEmpty else {
            currentSession = nil
            DispatchQueue.main.async {
                self.currentTranslation = ""
                self.latestSkeletonFrame = nil
            }
            return
        }

        session.endTime = Date()
        session.isComplete = true
        currentSession = nil

        DispatchQueue.main.async {
            self.completedSessions.append(session)
            self.currentTranslation = ""
            self.latestSkeletonFrame = nil
            self.onTranslationSessionComplete?(session)
        }
    }

    private func resetRuntimeState() {
        stateQueue.sync {
            backendSessionId = nil
            frameIndex = 0
            submittedFrameCount = 0
            isStartingSession = false
            isSendingFrame = false
            isInferring = false
            isStoppingSession = false
            lastSubmittedFrameAt = .distantPast
            lastInferenceAt = .distantPast
        }
        DispatchQueue.main.async {
            self.latestSkeletonFrame = nil
        }
    }

    private func ensureBackendSession() async {
        let shouldStart = stateQueue.sync { () -> Bool in
            if isStartingSession || backendSessionId != nil {
                return false
            }
            isStartingSession = true
            return true
        }
        guard shouldStart else { return }

        do {
            let health: BackendHealthResponse = try await sendRequest(path: "/api/v1/health", method: "GET")
            if !health.modelLoaded {
                let loaded: BackendHealthResponse = try await sendRequest(path: "/api/v1/runtime/load", method: "POST")
                await MainActor.run {
                    self.isModelLoaded = loaded.modelLoaded
                }
            } else {
                await MainActor.run {
                    self.isModelLoaded = health.modelLoaded
                }
            }

            let createRequest = BackendSessionCreateRequest(metadata: [
                "client": "ios-native",
                "platform": "ios",
                "app": "sign2text-app",
            ])
            let createResponse: BackendSessionCreateResponse = try await sendRequest(
                path: "/api/v1/translation/session",
                method: "POST",
                body: createRequest
            )

            stateQueue.sync {
                backendSessionId = createResponse.sessionId
                isStartingSession = false
            }

            await MainActor.run {
                self.connectionStatus = "Streaming"
                self.currentModel = "SLRT Backend"
                self.lastErrorMessage = nil
            }
        } catch {
            stateQueue.sync {
                isStartingSession = false
            }
            publishError(error)
            await MainActor.run {
                self.isTranslating = false
                self.connectionStatus = "Connection failed"
            }
            completeCurrentSession()
        }
    }

    private func finishBackendSession() async {
        let sessionId = stateQueue.sync { () -> String? in
            if isStoppingSession {
                return nil
            }
            isStoppingSession = true
            return backendSessionId
        }

        guard let sessionId else {
            completeCurrentSession()
            return
        }

        defer {
            resetRuntimeState()
        }

        do {
            let response: BackendTranslationEvent = try await sendRequest(
                path: "/api/v1/translation/session/\(sessionId)/finish",
                method: "POST"
            )
            applyTranslationEvent(response)
            completeCurrentSession(with: response.text)
            await MainActor.run {
                self.connectionStatus = "Stopped"
            }
        } catch {
            publishError(error)
            completeCurrentSession(with: currentSession?.translationText)
            await MainActor.run {
                self.connectionStatus = "Stopped with error"
            }
        }
    }

    private func reserveFrameSubmission(at now: Date) -> ReservedFrameSubmission? {
        stateQueue.sync {
            guard backendSessionId != nil else { return nil }
            guard !isSendingFrame else { return nil }
            guard now.timeIntervalSince(lastSubmittedFrameAt) >= frameSubmissionInterval else { return nil }
            let reservedFrameIndex = frameIndex
            frameIndex += 1
            isSendingFrame = true
            lastSubmittedFrameAt = now
            return ReservedFrameSubmission(
                frameIndex: reservedFrameIndex,
                timestampMs: Int(now.timeIntervalSince1970 * 1000)
            )
        }
    }

    private func submitFrame(encodedFrame: EncodedFramePayload, frameIndex: Int, timestampMs: Int) async {
        guard let sessionId = stateQueue.sync(execute: { backendSessionId }) else {
            stateQueue.sync {
                isSendingFrame = false
            }
            return
        }

        defer {
            stateQueue.sync {
                isSendingFrame = false
            }
        }

        do {
            let frameRequest = BackendFrameUploadRequest(
                frameIndex: frameIndex,
                timestampMs: timestampMs,
                imageJpegBase64: encodedFrame.imageJpegBase64,
                imageWidth: encodedFrame.imageWidth,
                imageHeight: encodedFrame.imageHeight
            )
            let response: BackendTranslationEvent = try await sendRequest(
                path: "/api/v1/translation/session/\(sessionId)/frame",
                method: "POST",
                body: frameRequest
            )
            applyTranslationEvent(response)

            let shouldInfer = stateQueue.sync { () -> Bool in
                submittedFrameCount += 1
                let enoughFrames = submittedFrameCount % inferenceEveryNFrames == 0
                let enoughTime = Date().timeIntervalSince(lastInferenceAt) >= inferenceInterval
                guard enoughFrames || enoughTime else { return false }
                guard !isInferring else { return false }
                isInferring = true
                lastInferenceAt = Date()
                return true
            }

            if shouldInfer {
                await inferSession(sessionId: sessionId)
            }
        } catch {
            publishError(error)
        }
    }

    private func inferSession(sessionId: String) async {
        defer {
            stateQueue.sync {
                isInferring = false
            }
        }

        do {
            let request = BackendInferenceRequest(predSrc: "ensemble")
            let response: BackendTranslationEvent = try await sendRequest(
                path: "/api/v1/translation/session/\(sessionId)/infer",
                method: "POST",
                body: request
            )
            applyTranslationEvent(response)
        } catch {
            publishError(error)
        }
    }

    private func applyTranslationEvent(_ response: BackendTranslationEvent) {
        if let skeletonFrame = response.skeletonFrame,
            let overlayFrame = SkeletonOverlayFrame(response: skeletonFrame)
        {
            DispatchQueue.main.async {
                self.latestSkeletonFrame = overlayFrame
            }
        }

        if let text = response.text, !text.isEmpty {
            currentSession?.translationText = text
            DispatchQueue.main.async {
                self.currentTranslation = text
                self.onCurrentTranslationUpdate?(text)
                self.connectionStatus = response.status == "ok" ? "Receiving translation" : response.status.capitalized
                self.lastErrorMessage = nil
            }
            return
        }

        DispatchQueue.main.async {
            self.connectionStatus = response.status.capitalized
        }
    }

    private func publishError(_ error: Error) {
        let message: String
        if let signLanguageError = error as? SignLanguageError {
            message = signLanguageError.localizedDescription
        } else if let backendError = error as? BackendServiceError {
            message = backendError.localizedDescription
        } else {
            message = error.localizedDescription
        }

        DispatchQueue.main.async {
            self.lastErrorMessage = message
            self.connectionStatus = "Error"
            self.onError?(error)
        }
    }

    private func normalizeBaseURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func looksLikeLoopbackURL(_ value: String) -> Bool {
        value.contains("127.0.0.1") || value.contains("localhost")
    }

    private func buildURL(path: String) throws -> URL {
        let normalized = normalizeBaseURL(backendURL)
        guard !normalized.isEmpty else {
            throw SignLanguageError.networkError("Backend URL is empty")
        }
        guard let url = URL(string: normalized + path) else {
            throw SignLanguageError.networkError("Invalid backend URL: \(normalized)")
        }
        return url
    }

    private func sendRequest<Response: Decodable>(path: String, method: String) async throws -> Response {
        try await sendRequest(path: path, method: method, body: Optional<String>.none as String?)
    }

    private func sendRequest<Request: Encodable, Response: Decodable>(path: String, method: String, body: Request? = nil) async throws -> Response {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SignLanguageError.networkError("Backend returned a non-HTTP response")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data), let detail = backendError.detail {
                throw BackendServiceError.server(detail)
            }
            let bodyText = String(data: data, encoding: .utf8) ?? "Unknown backend error"
            throw BackendServiceError.httpStatus(httpResponse.statusCode, bodyText)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func encodeFrame(_ frame: CIImage) -> EncodedFramePayload? {
        let extent = frame.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let scale = min(1.0, maxEncodedFrameDimension / max(extent.width, extent.height))
        let resizedFrame = scale < 1.0 ? frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) : frame
        let resizedExtent = resizedFrame.extent.integral

        guard let cgImage = ciContext.createCGImage(resizedFrame, from: resizedFrame.extent) else { return nil }

        #if canImport(UIKit)
            let image = UIImage(cgImage: cgImage)
            guard let data = image.jpegData(compressionQuality: jpegCompressionQuality) else { return nil }
            return EncodedFramePayload(
                imageJpegBase64: data.base64EncodedString(),
                imageWidth: max(Int(resizedExtent.width.rounded()), 1),
                imageHeight: max(Int(resizedExtent.height.rounded()), 1)
            )
        #else
            return nil
        #endif
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

private struct ReservedFrameSubmission {
    let frameIndex: Int
    let timestampMs: Int
}

private struct EncodedFramePayload {
    let imageJpegBase64: String
    let imageWidth: Int
    let imageHeight: Int
}

struct SkeletonKeypoint: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let confidence: CGFloat
}

struct SkeletonOverlayFrame {
    let frameIndex: Int
    let timestampMs: Int
    let sourceSize: CGSize
    let keypoints: [SkeletonKeypoint]

    init?(response: BackendSkeletonFrame) {
        guard response.sourceSize.width > 0, response.sourceSize.height > 0 else { return nil }
        let points = response.keypoints.compactMap { point -> SkeletonKeypoint? in
            guard point.count >= 2 else { return nil }
            return SkeletonKeypoint(
                x: CGFloat(point[0]),
                y: CGFloat(point[1]),
                confidence: CGFloat(point.count > 2 ? point[2] : 1.0)
            )
        }
        guard !points.isEmpty else { return nil }
        self.frameIndex = response.frameIndex
        self.timestampMs = response.timestampMs
        self.sourceSize = CGSize(width: response.sourceSize.width, height: response.sourceSize.height)
        self.keypoints = points
    }
}

private struct BackendHealthResponse: Decodable {
    let status: String
    let modelLoaded: Bool
    let poseExtractorLoaded: Bool
    let device: String
}

private struct BackendSessionCreateRequest: Encodable {
    let metadata: [String: String]
}

private struct BackendSessionCreateResponse: Decodable {
    let sessionId: String
    let createdAt: String
    let status: String
}

private struct BackendFrameUploadRequest: Encodable {
    let frameIndex: Int
    let timestampMs: Int
    let imageJpegBase64: String
    let imageWidth: Int
    let imageHeight: Int
}

private struct BackendInferenceRequest: Encodable {
    let predSrc: String
}

private struct BackendTranslationCandidate: Decodable {
    let decodeMethod: String
    let glossText: String
}

private struct BackendTranslationEvent: Decodable {
    let sessionId: String
    let type: String
    let status: String
    let frameCount: Int
    let keypointCount: Int
    let modelLoaded: Bool
    let text: String?
    let decodeMethod: String?
    let candidates: [BackendTranslationCandidate]
    let notes: [String]
    let skeletonFrame: BackendSkeletonFrame?
}

struct BackendFrameSize: Decodable {
    let width: Double
    let height: Double
}

struct BackendSkeletonFrame: Decodable {
    let frameIndex: Int
    let timestampMs: Int
    let sourceSize: BackendFrameSize
    let keypoints: [[Double]]
}

private struct BackendErrorResponse: Decodable {
    let detail: String?
}

private enum BackendServiceError: LocalizedError {
    case server(String)
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message
        case .httpStatus(let statusCode, let body):
            return "Backend HTTP \(statusCode): \(body)"
        }
    }
}
