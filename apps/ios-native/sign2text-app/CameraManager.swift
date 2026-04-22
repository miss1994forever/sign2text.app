//
//  CameraManager.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import AVFoundation
import Combine
import SwiftUI

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Published Properties

    /// Published camera output for SwiftUI views
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    /// Published permission status for camera access
    @Published var permissionGranted = false

    /// Published error message if camera setup fails
    @Published var errorMessage: String?

    /// Published camera status for real-time feedback
    @Published var isCameraActive = false

    /// Published frame rate information
    @Published var currentFrameRate: Double = 0.0

    /// Published frame count for debugging
    @Published var frameCount: Int = 0

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

    /// Current camera input device
    private var currentCameraInput: AVCaptureDeviceInput?

    /// Frame rate measurement
    private var lastFrameTime = CFAbsoluteTimeGetCurrent()
    private var frameRateCounter = 0

    /// Frame processing control
    private var frameSkipCounter = 0
    private let frameSkipInterval = 2  // Process every 3rd frame for better performance

    // MARK: - Callbacks

    /// Callback to deliver frames to the translation service for real-time processing
    var onFrameCaptured: ((CIImage) -> Void)?

    /// Callback for camera errors
    var onError: ((Error) -> Void)?

    /// Callback for permission changes
    var onPermissionChanged: ((Bool) -> Void)?

    var isFrontCameraActive: Bool {
        currentCameraInput?.device.position != .back
    }

    // MARK: - Initialization

    override init() {
        super.init()
        checkPermission()
        setupNotifications()
    }

    deinit {
        stopSession()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Checks for camera permission and requests if needed
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.permissionGranted = true
                self.onPermissionChanged?(true)
            }
            setupCamera()
        case .notDetermined:
            requestPermission()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionGranted = false
                self.errorMessage =
                    "Camera access is denied. Please enable camera access in Settings to use real-time sign language translation."
                self.onPermissionChanged?(false)
                self.onError?(
                    NSError(
                        domain: "CameraPermission", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"]))
            }
        @unknown default:
            DispatchQueue.main.async {
                self.permissionGranted = false
                self.errorMessage = "Unknown permission status. Please try again."
                self.onError?(
                    NSError(
                        domain: "CameraPermission", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown camera permission status"]))
            }
        }
    }

    /// Starts the camera capture session
    func startSession() {
        guard permissionGranted else {
            print("📷 Camera permission not granted, cannot start session")
            checkPermission()
            return
        }

        guard !captureSession.isRunning else {
            print("📷 Camera session already running")
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
                self.frameCount = 0
                self.currentFrameRate = 0.0
            }
        }

        print("📷 Stopped camera session")
    }

    /// Toggles between front and back camera
    func switchCamera() {
        let position: AVCaptureDevice.Position =
            currentCameraInput?.device.position == .front ? .back : .front

        sessionQueue.async {
            self.configureCameraInput(for: position)
        }
    }

    // MARK: - Private Methods

    /// Requests camera permission from the user
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                self?.onPermissionChanged?(granted)

                if granted {
                    self?.setupCamera()
                } else {
                    self?.errorMessage =
                        "Camera access is required for real-time sign language translation."
                    self?.onError?(
                        NSError(
                            domain: "CameraPermission", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"]))
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
                #if canImport(UIKit)
                    previewLayer.backgroundColor = UIColor.black.cgColor
                #endif
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
        configureCameraInput(for: .front)

        // Set up video output optimized for real-time processing
        setupVideoOutput()

        captureSession.commitConfiguration()
        print("📷 Camera configuration completed successfully")
    }

    /// Configures camera input for specified position
    private func configureCameraInput(for position: AVCaptureDevice.Position) {
        // Remove existing input
        if let currentInput = currentCameraInput {
            captureSession.removeInput(currentInput)
        }

        // Get camera device for specified position
        guard
            let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: position)
        else {
            print("📷 ERROR: Camera not available")
            DispatchQueue.main.async {
                self.errorMessage = "Camera not available on this device."
                self.onError?(
                    NSError(
                        domain: "CameraDevice", code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Camera device not available"]))
            }
            return
        }

        // Create input from camera device
        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            print("📷 ERROR: Could not create camera input")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create camera input."
                self.onError?(
                    NSError(
                        domain: "CameraInput", code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create camera input"]))
            }
            return
        }

        // Add input to session
        guard captureSession.canAddInput(input) else {
            print("📷 ERROR: Cannot add camera input to session")
            DispatchQueue.main.async {
                self.errorMessage = "Cannot add camera input to capture session."
                self.onError?(
                    NSError(
                        domain: "CameraInput", code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input to session"])
                )
            }
            return
        }

        captureSession.addInput(input)
        currentCameraInput = input

        print("📷 Camera input added successfully")

        // Configure camera settings
        configureCameraDevice(camera)
    }

    /// Configures camera device settings
    private func configureCameraDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            // Set frame rate for optimal real-time processing
            if let frameRateRange = device.activeFormat.videoSupportedFrameRateRanges.first(
                where: { $0.maxFrameRate >= 30 })
            {
                let targetFrameRate = min(30.0, frameRateRange.maxFrameRate)
                device.activeVideoMinFrameDuration = CMTime(
                    value: 1, timescale: Int32(targetFrameRate))
                device.activeVideoMaxFrameDuration = CMTime(
                    value: 1, timescale: Int32(targetFrameRate))
                print("📷 Set frame rate to \(targetFrameRate) fps")
            }

            // Optimize focus for hand/gesture recognition
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                print("📷 Set continuous autofocus")
            }

            // Optimize exposure for consistent lighting
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                print("📷 Set continuous auto exposure")
            }

            device.unlockForConfiguration()
        } catch {
            print("📷 Failed to configure camera settings: \(error)")
        }
    }

    /// Sets up video output for frame processing
    private func setupVideoOutput() {
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
                self.onError?(
                    NSError(
                        domain: "CameraOutput", code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot add video output to session"])
                )
            }
            return
        }

        captureSession.addOutput(videoOutput)
        print("📷 Video output added successfully")

        // Configure connection settings
        configureVideoOutputConnection()
    }

    /// Configures video output connection settings
    private func configureVideoOutputConnection() {
        guard let connection = videoOutput.connection(with: .video) else { return }

        // Mirror for front camera (natural for sign language users)
        if connection.isVideoMirroringSupported && currentCameraInput?.device.position == .front {
            connection.isVideoMirrored = true
            print("📷 Video mirroring enabled for front camera")
        }

        #if os(iOS)
            // Set orientation for optimal gesture capture
            if #available(iOS 17.0, *) {
                let rotationAngle: CGFloat = (currentCameraInput?.device.position == .front) ? 270 : 90
                if connection.isVideoRotationAngleSupported(rotationAngle) {
                    connection.videoRotationAngle = rotationAngle
                    print("📷 Video rotation angle set to \(rotationAngle) degrees")
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
                print("📷 Video orientation set to portrait")
            }
        #endif
    }

    /// Sets up notifications for camera events
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: captureSession
        )
    }

    /// Handles session interruption
    @objc private func sessionWasInterrupted(notification: NSNotification) {
        print("📷 Camera session was interrupted")
        DispatchQueue.main.async {
            self.isCameraActive = false
        }
    }

    /// Handles end of session interruption
    @objc private func sessionInterruptionEnded(notification: NSNotification) {
        print("📷 Camera session interruption ended")
        DispatchQueue.main.async {
            self.isCameraActive = true
        }
    }

    /// Updates frame rate calculation
    private func updateFrameRate() {
        frameRateCounter += 1
        let currentTime = CFAbsoluteTimeGetCurrent()
        let timeDiff = currentTime - lastFrameTime

        if timeDiff >= 1.0 {  // Update every second
            let fps = Double(frameRateCounter) / timeDiff

            DispatchQueue.main.async {
                self.currentFrameRate = fps
            }

            frameRateCounter = 0
            lastFrameTime = currentTime
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager {
    private func currentVideoRotationAngle(for connection: AVCaptureConnection) -> Int {
        if #available(iOS 17.0, *) {
            let normalized = connection.videoRotationAngle.truncatingRemainder(dividingBy: 360)
            return Int(normalized.rounded())
        }

        switch connection.videoOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeRight:
            return 0
        case .landscapeLeft:
            return 180
        @unknown default:
            return 90
        }
    }

    private func previewAlignedImage(from pixelBuffer: CVPixelBuffer, connection: AVCaptureConnection) -> CIImage {
        let image = CIImage(cvPixelBuffer: pixelBuffer)

        #if os(iOS)
            let exifOrientation: Int32
            switch currentVideoRotationAngle(for: connection) {
            case 90:
                exifOrientation = connection.isVideoMirrored ? 5 : 6
            case 270:
                exifOrientation = connection.isVideoMirrored ? 7 : 8
            case 0:
                exifOrientation = connection.isVideoMirrored ? 4 : 1
            case 180:
                exifOrientation = connection.isVideoMirrored ? 2 : 3
            default:
                exifOrientation = connection.isVideoMirrored ? 5 : 6
            }
            return image.oriented(forExifOrientation: Int(exifOrientation))
        #else
            return image
        #endif
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame rate control for performance optimization
        frameSkipCounter += 1
        guard frameSkipCounter % frameSkipInterval == 0 else { return }

        // Update frame rate calculation
        updateFrameRate()

        // Convert sample buffer to CIImage for processing
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = previewAlignedImage(from: pixelBuffer, connection: connection)

        // Pass the frame to the callback
        DispatchQueue.main.async { [weak self] in
            self?.onFrameCaptured?(ciImage)
        }

        // Update frame count
        DispatchQueue.main.async {
            self.frameCount += 1
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Handle dropped frames - useful for performance monitoring
        print("📷 Frame dropped - processing may be too slow")
    }
}
