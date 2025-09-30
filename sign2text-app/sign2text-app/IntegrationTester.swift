//
//  IntegrationTester.swift
//  sign2text-app
//
//  Comprehensive test script for CoreML integration components
//  Created by CV-SLT Integration on 2024/12/19.
//

import CoreImage
import CoreML
import Foundation
import SwiftUI
import UIKit

/// Comprehensive tester for all CoreML integration components
class IntegrationTester: ObservableObject {

    // MARK: - Published Properties

    @Published var testResults: [TestResult] = []
    @Published var isRunning = false
    @Published var currentTest = ""
    @Published var overallStatus: TestStatus = .pending

    // MARK: - Test Status

    enum TestStatus {
        case pending
        case running
        case passed
        case failed
        case warning

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .running: return "arrow.2.circlepath"
            case .passed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .pending: return .gray
            case .running: return .blue
            case .passed: return .green
            case .failed: return .red
            case .warning: return .orange
            }
        }
    }

    // MARK: - Test Result

    struct TestResult {
        let id = UUID()
        let name: String
        let status: TestStatus
        let message: String
        let duration: TimeInterval
        let details: [String: Any]?

        init(
            name: String, status: TestStatus, message: String, duration: TimeInterval,
            details: [String: Any]? = nil
        ) {
            self.name = name
            self.status = status
            self.message = message
            self.duration = duration
            self.details = details
        }
    }

    // MARK: - Test Components

    private var coreMLProcessor: SignLanguageProcessor?
    private var featureExtractor: SignLanguageFeatureExtractor?
    private var translationService: EnhancedTranslationService?

    // MARK: - Public Methods

    /// Run all integration tests
    func runAllTests() {
        guard !isRunning else { return }

        isRunning = true
        overallStatus = .running
        testResults.removeAll()

        DispatchQueue.global(qos: .userInitiated).async {
            self.executeTestSuite()
        }
    }

    /// Run a specific test
    func runSpecificTest(_ testName: String) {
        guard !isRunning else { return }

        isRunning = true
        overallStatus = .running
        testResults.removeAll()

        DispatchQueue.global(qos: .userInitiated).async {
            switch testName {
            case "CoreML Model": self.testCoreMLModel()
            case "Feature Extraction": self.testFeatureExtraction()
            case "Translation Service": self.testTranslationService()
            case "UI Integration": self.testUIIntegration()
            case "Performance": self.testPerformance()
            default: break
            }

            DispatchQueue.main.async {
                self.isRunning = false
                self.updateOverallStatus()
            }
        }
    }

    // MARK: - Test Suite Execution

    private func executeTestSuite() {
        let tests: [(String, () -> Void)] = [
            ("CoreML Model Loading", testCoreMLModel),
            ("Feature Extraction", testFeatureExtraction),
            ("Translation Service", testTranslationService),
            ("Integration Pipeline", testIntegrationPipeline),
            ("Performance Benchmarks", testPerformance),
            ("Memory Management", testMemoryUsage),
            ("Error Handling", testErrorHandling),
            ("UI Components", testUIIntegration),
        ]

        for (testName, testFunction) in tests {
            DispatchQueue.main.async {
                self.currentTest = testName
            }

            testFunction()

            // Small delay between tests
            Thread.sleep(forTimeInterval: 0.5)
        }

        DispatchQueue.main.async {
            self.isRunning = false
            self.currentTest = ""
            self.updateOverallStatus()
        }
    }

    // MARK: - Individual Tests

    private func testCoreMLModel() {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Test 1: Model file exists and loads
            let processor = SignLanguageProcessor()
            self.coreMLProcessor = processor

            // Create test input
            let featuresArray = try MLMultiArray(shape: [1, 50, 512], dataType: .float32)
            let lengthsArray = try MLMultiArray(shape: [1], dataType: .int32)

            // Fill with test data
            for i in 0..<featuresArray.count {
                featuresArray[i] = NSNumber(value: Float.random(in: -1...1))
            }
            lengthsArray[0] = NSNumber(value: 50)

            // Test 2: Model inference
            let testFeatures = (0..<50).map { _ in
                Array(repeating: Float.random(in: -1...1), count: 512)
            }

            if let result = processor.processSignLanguageFeatures(testFeatures) {
                let duration = CFAbsoluteTimeGetCurrent() - startTime

                let details: [String: Any] = [
                    "outputDimension": result.count,
                    "outputRange": "\(result.min() ?? 0) to \(result.max() ?? 0)",
                    "inferenceTime": String(format: "%.2f ms", duration * 1000),
                ]

                addTestResult(
                    name: "CoreML Model",
                    status: .passed,
                    message:
                        "Model loads and processes input successfully. Output: \(result.count) dimensions",
                    duration: duration,
                    details: details
                )
            } else {
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                addTestResult(
                    name: "CoreML Model",
                    status: .failed,
                    message: "Model inference failed - no output returned",
                    duration: duration
                )
            }

        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            addTestResult(
                name: "CoreML Model",
                status: .failed,
                message: "Model loading failed: \(error.localizedDescription)",
                duration: duration
            )
        }
    }

    private func testFeatureExtraction() {
        let startTime = CFAbsoluteTimeGetCurrent()

        let extractor = SignLanguageFeatureExtractor()
        self.featureExtractor = extractor

        // Create test image
        let testImage = createTestImage()

        var testPassed = false
        var extractedFeatures: [[Float]] = []

        let expectation = DispatchSemaphore(value: 0)

        extractor.processFrame(testImage) { features in
            extractedFeatures = features
            testPassed = !features.isEmpty && features.first?.count == 512
            expectation.signal()
        }

        // Wait for async completion
        _ = expectation.wait(timeout: .now() + 5.0)

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        if testPassed {
            let details: [String: Any] = [
                "framesExtracted": extractedFeatures.count,
                "featureDimension": extractedFeatures.first?.count ?? 0,
                "extractionTime": String(format: "%.2f ms", duration * 1000),
            ]

            addTestResult(
                name: "Feature Extraction",
                status: .passed,
                message:
                    "Successfully extracted \(extractedFeatures.count) frames with 512-dim features",
                duration: duration,
                details: details
            )
        } else {
            addTestResult(
                name: "Feature Extraction",
                status: .failed,
                message: "Feature extraction failed or returned invalid dimensions",
                duration: duration
            )
        }
    }

    private func testTranslationService() {
        let startTime = CFAbsoluteTimeGetCurrent()

        let service = EnhancedTranslationService()
        self.translationService = service

        // Wait for model to initialize
        Thread.sleep(forTimeInterval: 2.0)

        if service.isModelLoaded {
            // Test translation session
            service.startTranslationSession()

            // Process test frames
            let testFrames = (0..<5).map { _ in createTestImage() }

            var translationReceived = false
            let expectation = DispatchSemaphore(value: 0)

            service.processVideoFrames(testFrames) { text, confidence in
                translationReceived = !text.isEmpty && confidence > 0
                expectation.signal()
            }

            _ = expectation.wait(timeout: .now() + 10.0)

            service.stopTranslationSession()

            let duration = CFAbsoluteTimeGetCurrent() - startTime

            if translationReceived {
                let (inferences, avgTime, successRate) = service.getPerformanceMetrics()

                let details: [String: Any] = [
                    "modelLoaded": service.isModelLoaded,
                    "inferencesRun": inferences,
                    "averageInferenceTime": String(format: "%.2f ms", avgTime),
                    "successRate": String(format: "%.1f%%", successRate * 100),
                ]

                addTestResult(
                    name: "Translation Service",
                    status: .passed,
                    message:
                        "Translation service works. Avg inference: \(String(format: "%.1f ms", avgTime))",
                    duration: duration,
                    details: details
                )
            } else {
                addTestResult(
                    name: "Translation Service",
                    status: .failed,
                    message: "Translation service failed to produce results",
                    duration: duration
                )
            }
        } else {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            addTestResult(
                name: "Translation Service",
                status: .failed,
                message: "Translation service failed to load CoreML model",
                duration: duration
            )
        }
    }

    private func testIntegrationPipeline() {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let processor = coreMLProcessor,
            let extractor = featureExtractor,
            let service = translationService
        else {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            addTestResult(
                name: "Integration Pipeline",
                status: .failed,
                message: "Required components not initialized",
                duration: duration
            )
            return
        }

        // Test full pipeline: Image -> Features -> CoreML -> Text
        let testImage = createTestImage()
        var pipelineSuccess = false

        let expectation = DispatchSemaphore(value: 0)

        extractor.processFrame(testImage) { features in
            if !features.isEmpty,
                let embeddings = processor.processSignLanguageFeatures(features),
                !embeddings.isEmpty
            {
                pipelineSuccess = true
            }
            expectation.signal()
        }

        _ = expectation.wait(timeout: .now() + 5.0)

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        if pipelineSuccess {
            addTestResult(
                name: "Integration Pipeline",
                status: .passed,
                message:
                    "Full pipeline (Image -> Features -> CoreML -> Embeddings) works correctly",
                duration: duration
            )
        } else {
            addTestResult(
                name: "Integration Pipeline",
                status: .failed,
                message: "Integration pipeline failed at some stage",
                duration: duration
            )
        }
    }

    private func testPerformance() {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let processor = coreMLProcessor else {
            addTestResult(
                name: "Performance",
                status: .failed,
                message: "CoreML processor not available",
                duration: 0
            )
            return
        }

        // Performance benchmark: 100 inferences
        let iterations = 100
        var inferenceTimes: [Double] = []

        for _ in 0..<iterations {
            let testFeatures = (0..<50).map { _ in
                Array(repeating: Float.random(in: -1...1), count: 512)
            }

            let inferenceStart = CFAbsoluteTimeGetCurrent()
            let _ = processor.processSignLanguageFeatures(testFeatures)
            let inferenceTime = CFAbsoluteTimeGetCurrent() - inferenceStart

            inferenceTimes.append(inferenceTime * 1000)  // Convert to ms
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        let avgInferenceTime = inferenceTimes.reduce(0, +) / Double(inferenceTimes.count)
        let minTime = inferenceTimes.min() ?? 0
        let maxTime = inferenceTimes.max() ?? 0

        let details: [String: Any] = [
            "iterations": iterations,
            "averageTime": String(format: "%.2f ms", avgInferenceTime),
            "minTime": String(format: "%.2f ms", minTime),
            "maxTime": String(format: "%.2f ms", maxTime),
            "throughput": String(format: "%.1f inferences/sec", 1000.0 / avgInferenceTime),
        ]

        let status: TestStatus =
            avgInferenceTime < 10.0 ? .passed : (avgInferenceTime < 50.0 ? .warning : .failed)
        let message =
            "Average inference: \(String(format: "%.2f ms", avgInferenceTime)) (\(iterations) iterations)"

        addTestResult(
            name: "Performance",
            status: status,
            message: message,
            duration: duration,
            details: details
        )
    }

    private func testMemoryUsage() {
        let startTime = CFAbsoluteTimeGetCurrent()

        let initialMemory = getMemoryUsage()

        // Create and destroy multiple service instances
        for _ in 0..<5 {
            let service = EnhancedTranslationService()
            let extractor = SignLanguageFeatureExtractor()

            // Process some data
            let testImage = createTestImage()
            let expectation = DispatchSemaphore(value: 0)

            extractor.processFrame(testImage) { _ in
                expectation.signal()
            }

            _ = expectation.wait(timeout: .now() + 1.0)
        }

        // Force garbage collection
        autoreleasepool {}

        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        let details: [String: Any] = [
            "initialMemory": String(format: "%.1f MB", initialMemory),
            "finalMemory": String(format: "%.1f MB", finalMemory),
            "memoryIncrease": String(format: "%.1f MB", memoryIncrease),
        ]

        let status: TestStatus =
            memoryIncrease < 50.0 ? .passed : (memoryIncrease < 100.0 ? .warning : .failed)
        let message = "Memory usage increase: \(String(format: "%.1f MB", memoryIncrease))"

        addTestResult(
            name: "Memory Management",
            status: status,
            message: message,
            duration: duration,
            details: details
        )
    }

    private func testErrorHandling() {
        let startTime = CFAbsoluteTimeGetCurrent()

        let processor = SignLanguageProcessor()
        var errorsCaughtCorrectly = 0
        let totalErrorTests = 3

        // Test 1: Invalid input dimensions
        let invalidFeatures = [[Float]]()  // Empty features
        if processor.processSignLanguageFeatures(invalidFeatures) == nil {
            errorsCaughtCorrectly += 1
        }

        // Test 2: Malformed feature dimensions
        let malformedFeatures: [[Float]] = [[1.0, 2.0]]  // Wrong dimension
        if processor.processSignLanguageFeatures(malformedFeatures) == nil {
            errorsCaughtCorrectly += 1
        }

        // Test 3: Extreme values
        let extremeFeatures = (0..<50).map { _ in
            Array(repeating: Float.greatestFiniteMagnitude, count: 512)
        }
        let result = processor.processSignLanguageFeatures(extremeFeatures)
        if result != nil && result!.allSatisfy({ $0.isFinite }) {
            errorsCaughtCorrectly += 1
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        let details: [String: Any] = [
            "errorTestsPassed": errorsCaughtCorrectly,
            "totalErrorTests": totalErrorTests,
        ]

        let status: TestStatus = errorsCaughtCorrectly == totalErrorTests ? .passed : .warning
        let message = "Error handling: \(errorsCaughtCorrectly)/\(totalErrorTests) tests passed"

        addTestResult(
            name: "Error Handling",
            status: status,
            message: message,
            duration: duration,
            details: details
        )
    }

    private func testUIIntegration() {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Test UI component initialization
        let service = EnhancedTranslationService()

        // Wait briefly for initialization
        Thread.sleep(forTimeInterval: 1.0)

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Basic UI integration test
        let uiTestsPassed = [
            service.isModelLoaded,  // Model should load
            !service.isTranslating,  // Should start in idle state
            service.completedSessions.isEmpty,  // Should start with no history
        ].allSatisfy { $0 }

        let details: [String: Any] = [
            "modelLoaded": service.isModelLoaded,
            "initialTranslatingState": service.isTranslating,
            "emptyHistory": service.completedSessions.isEmpty,
        ]

        addTestResult(
            name: "UI Integration",
            status: uiTestsPassed ? .passed : .warning,
            message: uiTestsPassed
                ? "UI components initialize correctly" : "Some UI components may have issues",
            duration: duration,
            details: details
        )
    }

    // MARK: - Helper Methods

    private func addTestResult(
        name: String, status: TestStatus, message: String, duration: TimeInterval,
        details: [String: Any]? = nil
    ) {
        DispatchQueue.main.async {
            let result = TestResult(
                name: name,
                status: status,
                message: message,
                duration: duration,
                details: details
            )
            self.testResults.append(result)
        }
    }

    private func updateOverallStatus() {
        if testResults.isEmpty {
            overallStatus = .pending
            return
        }

        if testResults.contains(where: { $0.status == .failed }) {
            overallStatus = .failed
        } else if testResults.contains(where: { $0.status == .warning }) {
            overallStatus = .warning
        } else if testResults.allSatisfy({ $0.status == .passed }) {
            overallStatus = .passed
        } else {
            overallStatus = .running
        }
    }

    private func createTestImage() -> CIImage {
        // Create a simple test image with some patterns
        let size = CGSize(width: 224, height: 224)

        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }

        let context = UIGraphicsGetCurrentContext()!

        // Fill with gradient background
        let colors = [UIColor.blue.cgColor, UIColor.red.cgColor]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!

        context.drawLinearGradient(
            gradient,
            start: CGPoint.zero,
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )

        // Add some geometric shapes to create features
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 50, y: 50, width: 50, height: 50))

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 100, y: 100, width: 60, height: 40))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        return CIImage(cgImage: image.cgImage!)
    }

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0  // Convert to MB
        } else {
            return 0.0
        }
    }
}

// MARK: - Test Result View

struct TestResultView: View {
    let result: IntegrationTester.TestResult
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.status.icon)
                    .foregroundColor(result.status.color)
                    .font(.title3)

                VStack(alignment: .leading) {
                    Text(result.name)
                        .font(.headline)

                    Text(result.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(String(format: "%.0f", result.duration * 1000))ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let details = result.details, !details.isEmpty {
                Button(showDetails ? "Hide Details" : "Show Details") {
                    showDetails.toggle()
                }
                .font(.caption)

                if showDetails {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(details.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text("\(key):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(details[key] as? String ?? "\(details[key] ?? "")")")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Integration Test View

struct IntegrationTestView: View {
    @StateObject private var tester = IntegrationTester()

    var body: some View {
        NavigationView {
            VStack {
                // Overall Status
                HStack {
                    Image(systemName: tester.overallStatus.icon)
                        .foregroundColor(tester.overallStatus.color)
                        .font(.title2)

                    Text(tester.isRunning ? "Running Tests..." : "Integration Tests")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    if !tester.isRunning {
                        Button("Run All Tests") {
                            tester.runAllTests()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()

                // Current Test
                if tester.isRunning && !tester.currentTest.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Running: \(tester.currentTest)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Test Results
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tester.testResults, id: \.id) { result in
                            TestResultView(result: result)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Preview

struct IntegrationTestView_Previews: PreviewProvider {
    static var previews: some View {
        IntegrationTestView()
    }
}
