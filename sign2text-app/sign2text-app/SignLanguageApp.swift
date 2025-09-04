//
//  SignLanguageApp.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import AVFoundation
import Combine
import CoreImage
import Foundation
import SwiftUI

// MARK: - Camera Preview UIViewRepresentable

#if canImport(UIKit)
    import UIKit

    struct CameraPreview: UIViewRepresentable {
        let previewLayer: AVCaptureVideoPreviewLayer

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = UIColor.black

            // Ensure the preview layer is properly configured
            DispatchQueue.main.async {
                self.previewLayer.frame = view.bounds
                if self.previewLayer.superlayer == nil {
                    view.layer.addSublayer(self.previewLayer)
                }
            }

            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            DispatchQueue.main.async {
                self.previewLayer.frame = uiView.bounds
            }
        }
    }
#else
    struct CameraPreview: View {
        let previewLayer: AVCaptureVideoPreviewLayer

        var body: some View {
            Rectangle()
                .fill(Color.black)
                .overlay(
                    Text("Camera Preview Not Available on this platform")
                        .foregroundColor(.white)
                )
        }
    }
#endif

// MARK: - Translation Service

/// A service that handles real-time translation of sign language captured via camera frames into text.
/// Current implementation uses dummy logic for demonstration, designed to be easily replaced with a real ML model.
class SignLanguageTranslationService: ObservableObject {
    // MARK: - Properties

    /// Callback to deliver translated text to the UI in real-time
    var onTranslationUpdate: ((String) -> Void)?

    /// Flag to determine if real-time translation is currently active
    private var isTranslating = false

    /// Timer to simulate real-time translation updates
    private var translationTimer: Timer?

    /// Queue for processing camera frames
    private let processingQueue = DispatchQueue(
        label: "translation.processing.queue", qos: .userInitiated)

    /// Frame processing counter to simulate model processing
    private var frameCount = 0

    /// Example preset sentences for dummy real-time translation
    private let dummyTranslations = [
        "你好",
        "谢谢",
        "请",
        "再见",
        "我爱你",
        "对不起",
        "没关系",
        "我需要帮助",
        "今天天气很好",
        "我很高兴见到你",
        "这个多少钱？",
        "我不明白",
        "请再说一遍",
        "祝你好运",
        "生日快乐",
    ]

    /// Current index in the dummy translations array
    private var currentTranslationIndex = 0

    /// Last translation time to control frequency
    private var lastTranslationTime = Date()

    /// Minimum interval between translations (in seconds)
    private let translationInterval: TimeInterval = 2.0

    // MARK: - Public Methods

    /// Starts the real-time translation process
    func startTranslation() {
        guard !isTranslating else { return }

        isTranslating = true
        frameCount = 0
        currentTranslationIndex = 0
        lastTranslationTime = Date()

        print("🚀 Starting real-time sign language translation...")

        // Start periodic translation simulation for real-time effect
        translationTimer = Timer.scheduledTimer(
            withTimeInterval: translationInterval, repeats: true
        ) { [weak self] _ in
            self?.simulateRealTimeTranslation()
        }
    }

    /// Processes a single camera frame for real-time translation
    /// - Parameter frame: The image frame from the camera
    func processFrame(_ frame: CIImage) {
        guard isTranslating else { return }

        // Process frames asynchronously to avoid blocking the camera feed
        processingQueue.async { [weak self] in
            self?.processFrameInternal(frame)
        }
    }

    /// Stops the real-time translation process
    func stopTranslation() {
        guard isTranslating else { return }

        isTranslating = false
        translationTimer?.invalidate()
        translationTimer = nil

        print("⏹️ Stopped real-time sign language translation")
    }

    // MARK: - Private Methods

    /// Internal frame processing method
    /// - Parameter frame: The CIImage frame to process
    private func processFrameInternal(_ frame: CIImage) {
        frameCount += 1

        // Simulate processing every Nth frame to reduce computational load
        // In a real implementation, this would be where you'd run your ML model
        if frameCount % 30 == 0 {  // Process every 30th frame (roughly once per second at 30fps)

            // Simulate ML model processing time
            let processingDelay = Double.random(in: 0.1...0.3)

            DispatchQueue.main.asyncAfter(deadline: .now() + processingDelay) { [weak self] in
                self?.handleFrameProcessingResult()
            }
        }
    }

    /// Handles the result of frame processing
    private func handleFrameProcessingResult() {
        // Check if enough time has passed since last translation
        let now = Date()
        guard now.timeIntervalSince(lastTranslationTime) >= translationInterval else {
            return
        }

        // Simulate confidence threshold - only "translate" if confidence is high enough
        let confidence = Double.random(in: 0.0...1.0)
        let confidenceThreshold = 0.7

        if confidence >= confidenceThreshold {
            deliverTranslation()
            lastTranslationTime = now
        }
    }

    /// Simulates real-time translation by delivering preset sentences
    private func simulateRealTimeTranslation() {
        guard isTranslating else { return }

        deliverTranslation()
    }

    /// Delivers a translation to the UI
    private func deliverTranslation() {
        guard currentTranslationIndex < dummyTranslations.count else {
            // Cycle back to the beginning
            currentTranslationIndex = 0
            return
        }

        let translation = dummyTranslations[currentTranslationIndex]

        // Add timestamp for real-time feel
        let timestamp = DateFormatter.localizedString(
            from: Date(), dateStyle: .none, timeStyle: .medium)
        let translationWithTime = "[\(timestamp)] \(translation)"

        print("🔤 Translation: \(translation)")

        // Deliver translation to UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onTranslationUpdate?(translationWithTime)
        }

        currentTranslationIndex += 1
    }
}

// MARK: - Camera Manager

class SignLanguageCameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Published camera output for SwiftUI views
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    /// Published permission status for camera access
    @Published var permissionGranted = false

    /// Published error message if camera setup fails
    @Published var errorMessage: String?

    /// Published camera status for real-time feedback
    @Published var isCameraActive = false

    // MARK: - Private Properties

    /// Capture session for camera
    private let captureSession = AVCaptureSession()

    /// Serial queue for camera operations
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    /// Video output for camera frames
    private let videoOutput = AVCaptureVideoDataOutput()

    /// Frame processing queue for real-time translation
    private let frameProcessingQueue = DispatchQueue(
        label: "camera.frame.processing", qos: .userInitiated)

    /// Callback to deliver frames to the translation service for real-time processing
    var onFrameCaptured: ((CIImage) -> Void)?

    /// Frame rate control for performance optimization
    private var frameSkipCounter = 0
    private let frameSkipInterval = 2  // Process every 3rd frame for better performance

    // MARK: - Initialization

    override init() {
        super.init()
        checkPermission()
    }

    // MARK: - Public Methods

    /// Checks for camera permission
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.permissionGranted = true
            }
            setupCamera()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionGranted = false
                self.errorMessage =
                    "Camera access is denied. Please enable camera access in Settings to use real-time sign language translation."
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionGranted = false
                self.errorMessage = "Unknown permission status. Please try again."
            }
        }
    }

    /// Starts the camera capture session
    func startSession() {
        guard !captureSession.isRunning else {
            print("📷 Camera session already running")
            return
        }

        guard permissionGranted else {
            print("📷 Camera permission not granted, cannot start session")
            checkPermission()
            return
        }

        sessionQueue.async {
            print("📷 Starting camera capture session...")
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isCameraActive = true
                print("📷 Camera session started successfully")
            }
        }
    }

    /// Stops the camera capture session
    func stopSession() {
        guard captureSession.isRunning else { return }

        sessionQueue.async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isCameraActive = false
            }
        }

        print("📷 Stopped camera session")
    }

    // MARK: - Private Methods

    /// Requests camera permission from the user
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if granted {
                    self?.setupCamera()
                } else {
                    self?.errorMessage =
                        "Camera access is required for real-time sign language translation."
                }
            }
        }
    }

    /// Sets up the camera capture session optimized for real-time processing
    private func setupCamera() {
        print("📷 Setting up camera...")
        sessionQueue.async {
            self.setupCaptureSession()

            DispatchQueue.main.async {
                let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.backgroundColor = UIColor.black.cgColor
                self.previewLayer = previewLayer
                print("📷 Camera setup completed")
            }
        }
    }

    /// Configures the capture session with input and output devices optimized for real-time processing
    private func setupCaptureSession() {
        print("📷 Configuring capture session...")

        // Begin configuration
        captureSession.beginConfiguration()

        // Set up the capture quality - balanced for real-time processing
        if captureSession.canSetSessionPreset(.medium) {
            captureSession.sessionPreset = .medium
            print("📷 Set session preset to medium")
        }

        // Set up camera input (front camera for sign language)
        guard
            let frontCamera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front)
        else {
            print("📷 ERROR: Front camera not available")
            DispatchQueue.main.async {
                self.errorMessage = "Front camera not available on this device."
            }
            captureSession.commitConfiguration()
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: frontCamera) else {
            print("📷 ERROR: Could not create camera input")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create camera input."
            }
            captureSession.commitConfiguration()
            return
        }

        guard captureSession.canAddInput(input) else {
            print("📷 ERROR: Cannot add camera input to session")
            DispatchQueue.main.async {
                self.errorMessage = "Cannot add camera input to capture session."
            }
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(input)
        print("📷 Camera input added successfully")

        // Configure camera settings for optimal sign language capture
        do {
            try frontCamera.lockForConfiguration()

            // Set frame rate for optimal real-time processing (30fps)
            if let frameRateRange = frontCamera.activeFormat.videoSupportedFrameRateRanges.first(
                where: { $0.maxFrameRate >= 30 })
            {
                let targetFrameRate = min(30.0, frameRateRange.maxFrameRate)
                frontCamera.activeVideoMinFrameDuration = CMTime(
                    value: 1, timescale: Int32(targetFrameRate))
                frontCamera.activeVideoMaxFrameDuration = CMTime(
                    value: 1, timescale: Int32(targetFrameRate))
                print("📷 Set frame rate to \(targetFrameRate) fps")
            }

            // Optimize focus for hand/gesture recognition
            if frontCamera.isFocusModeSupported(.continuousAutoFocus) {
                frontCamera.focusMode = .continuousAutoFocus
                print("📷 Set continuous autofocus")
            }

            // Optimize exposure for consistent lighting
            if frontCamera.isExposureModeSupported(.continuousAutoExposure) {
                frontCamera.exposureMode = .continuousAutoExposure
                print("📷 Set continuous auto exposure")
            }

            frontCamera.unlockForConfiguration()
        } catch {
            print("📷 Failed to configure camera settings: \(error)")
        }

        // Set up video output optimized for real-time processing
        videoOutput.setSampleBufferDelegate(self, queue: frameProcessingQueue)

        // Configure video output settings for better performance
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        // Drop frames if processing is too slow to maintain real-time performance
        videoOutput.alwaysDiscardsLateVideoFrames = true

        guard captureSession.canAddOutput(videoOutput) else {
            print("📷 ERROR: Cannot add video output to session")
            DispatchQueue.main.async {
                self.errorMessage = "Cannot add video output to capture session."
            }
            captureSession.commitConfiguration()
            return
        }

        captureSession.addOutput(videoOutput)
        print("📷 Video output added successfully")

        // Configure connection settings
        if let connection = videoOutput.connection(with: .video) {
            // Mirror for front camera (natural for sign language users)
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
                print("📷 Video mirroring enabled")
            }

            // Set orientation for optimal gesture capture
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                print("📷 Video orientation set to portrait")
            }
        }

        captureSession.commitConfiguration()
        print("📷 Camera configuration completed successfully")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension SignLanguageCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame rate control for performance optimization
        frameSkipCounter += 1
        guard frameSkipCounter % frameSkipInterval == 0 else { return }

        // Convert sample buffer to CIImage for processing
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Pass the frame to the translation service on main thread
        // This is where real-time sign language processing happens
        DispatchQueue.main.async { [weak self] in
            self?.onFrameCaptured?(ciImage)
        }
    }
}

// MARK: - Main Content View

struct SignLanguageContentView: View {
    // MARK: - State Properties
    @StateObject private var cameraManager = SignLanguageCameraManager()
    @StateObject private var translationService = SignLanguageTranslationService()

    @State private var isTranslating = false
    @State private var transcriptions: [String] = []

    // MARK: - View Body
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)

            // Main content
            VStack(spacing: 0) {
                // Camera view for real-time sign language capture
                ZStack {
                    if let previewLayer = cameraManager.previewLayer {
                        CameraPreview(previewLayer: previewLayer)
                            .edgesIgnoringSafeArea(.all)
                    } else {
                        Color.black
                            .overlay(
                                Text("Camera not available")
                                    .foregroundColor(.white)
                            )
                    }

                    // Real-time translation indicator
                    if isTranslating {
                        VStack {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                Text("Translating...")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Real-time transcription display area
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(transcriptions.enumerated()), id: \.offset) {
                                    index, text in
                                    Text(text)
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 4)
                                        .id(index)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                        .onChange(of: transcriptions.count) { oldValue, newValue in
                            if !transcriptions.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(transcriptions.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(12)
                    .frame(height: 150)
                    .padding()

                    // Control button for starting/stopping real-time translation
                    Button(action: toggleTranslation) {
                        HStack {
                            Image(systemName: isTranslating ? "stop.fill" : "play.fill")
                            Text(isTranslating ? "Stop Translation" : "Start Translation")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(isTranslating ? Color.red : Color.green)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                    }
                    .padding(.bottom, 30)
                }
            }

            // Camera permission overlay
            if !cameraManager.permissionGranted {
                ZStack {
                    Color.black.opacity(0.85)
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)

                        Text("Camera Permission Required")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(
                            "SignScribe needs camera access to translate sign language into text in real-time."
                        )
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                        Button(action: {
                            #if canImport(UIKit)
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            #endif
                        }) {
                            Text("Open Settings")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            setupRealTimeTranslation()
        }
        .onDisappear {
            stopTranslation()
            cameraManager.stopSession()
        }
    }

    // MARK: - Methods

    /// Sets up real-time translation service
    private func setupRealTimeTranslation() {
        // Configure the translation service for real-time updates
        translationService.onTranslationUpdate = { text in
            DispatchQueue.main.async {
                self.transcriptions.append(text)
            }
        }

        // Configure camera manager to continuously send frames for translation
        cameraManager.onFrameCaptured = { frame in
            if self.isTranslating {
                self.translationService.processFrame(frame)
            }
        }
    }

    /// Toggles real-time translation on/off
    private func toggleTranslation() {
        isTranslating.toggle()

        if isTranslating {
            startRealTimeTranslation()
        } else {
            stopTranslation()
        }
    }

    /// Starts real-time sign language translation
    private func startRealTimeTranslation() {
        // Clear previous transcriptions for new session
        transcriptions.removeAll()

        // Start camera session
        cameraManager.startSession()

        // Start translation service (dummy implementation will simulate real-time translation)
        translationService.startTranslation()
    }

    /// Stops real-time translation
    private func stopRealTimeTranslation() {
        translationService.stopTranslation()
        // Keep camera running for preview, just stop processing frames for translation
    }
}

// MARK: - Main App

@main
struct SignLanguageApp: App {
    var body: some Scene {
        WindowGroup {
            SignLanguageContentView()
        }
    }
}

// MARK: - Preview

struct SignLanguageContentView_Previews: PreviewProvider {
    static var previews: some View {
        SignLanguageContentView()
    }
}
