//
//  ContentViewEnhanced.swift
//  sign2text-app
//
//  Enhanced ContentView with CoreML integration
//  Created by CV-SLT Integration on 2024/12/19.
//

import AVFoundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Enhanced ContentView

struct ContentViewEnhanced: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var themeManager: ThemeManager

    // Use enhanced translation service
    @StateObject private var translationService = EnhancedTranslationService()

    // UI State
    @State private var showingDictionary = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showPermissionAlert = false
    @State private var showingDebugInfo = false

    // Translation State
    @State private var isTranslating = false
    @State private var translationHistory: [String] = []

    // Performance Monitoring
    @State private var debugInfo: [String: Any] = [:]
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Header with model status
                    headerView

                    // Camera preview with overlay
                    cameraPreviewSection

                    // Translation controls
                    translationControlsSection

                    // Current translation display
                    translationDisplaySection

                    // Translation history
                    historySection

                    Spacer()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force stack style for iPad compatibility
        .onAppear {
            setupTranslationService()
            cameraManager.checkPermission()  // Add missing camera permission check
            startPerformanceMonitoring()
        }
        .onDisappear {
            stopPerformanceMonitoring()
        }
        .sheet(isPresented: $showingDictionary) {
            DictionaryView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingHistory) {
            TranslationHistoryView(sessions: translationService.completedSessions)
                .environmentObject(themeManager)
        }
        .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Camera access is required for sign language translation. Please enable camera access in Settings."
            )
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("SignScribe AI")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.primaryText)

                HStack {
                    Circle()
                        .fill(translationService.isModelLoaded ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(translationService.isModelLoaded ? "CV-SLT Ready" : "Model Loading...")
                        .font(.caption)
                        .foregroundColor(themeManager.colors.secondaryText)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                // Debug info button (only show if model loaded)
                if translationService.isModelLoaded {
                    Button(action: { showingDebugInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundColor(themeManager.colors.primaryText)
                    }
                }

                Button(action: { showingHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(themeManager.colors.primaryText)
                }

                Button(action: { showingDictionary = true }) {
                    Image(systemName: "book.closed")
                        .font(.title3)
                        .foregroundColor(themeManager.colors.primaryText)
                }

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(themeManager.colors.primaryText)
                }
            }
        }
        .padding()
    }

    // MARK: - Camera Preview Section

    private var cameraPreviewSection: some View {
        ZStack {
            // Camera preview
            if let previewLayer = cameraManager.previewLayer {
                CameraPreview(previewLayer: previewLayer)
                .frame(height: 300)
                .background(Color.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isTranslating ? Color.green : themeManager.colors.accent,
                            lineWidth: isTranslating ? 3 : 1
                        )
                )

            // Processing status overlay
            if isTranslating {
                VStack {
                    Spacer()

                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.5)
                            .animation(
                                .easeInOut(duration: 1).repeatForever(), value: isTranslating)

                        Text(translationService.processingStatus.description)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            }

            // Performance indicator (top right)
            if isTranslating && translationService.frameProcessingRate > 0 {
                VStack {
                    HStack {
                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(
                                "\(String(format: "%.1f", translationService.frameProcessingRate)) FPS"
                            )
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }

                    Spacer()
                }
            }
        } else {
                // Fallback when camera preview is not available
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(height: 300)
                    .overlay(
                        Text("Camera not available")
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Translation Controls

    private var translationControlsSection: some View {
        HStack(spacing: 20) {
            // Start/Stop Translation Button
            Button(action: toggleTranslation) {
                HStack {
                    Image(systemName: isTranslating ? "stop.fill" : "play.fill")
                        .font(.title3)

                    Text(isTranslating ? "Stop Translation" : "Start Translation")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    isTranslating
                        ? Color.red
                        : (translationService.isModelLoaded
                            ? themeManager.colors.accent : Color.gray)
                )
                .cornerRadius(25)
            }
            .disabled(!translationService.isModelLoaded || !cameraManager.permissionGranted)

            // Clear History Button
            if !translationService.completedSessions.isEmpty {
                Button(action: clearHistory) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundColor(themeManager.colors.primaryText)
                        .padding(8)
                }
            }
        }
        .padding()
    }

    // MARK: - Translation Display

    private var translationDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Translation")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primaryText)

                if translationService.translationConfidence > 0 {
                    Spacer()

                    Text(
                        "\(String(format: "%.0f%%", translationService.translationConfidence * 100))"
                    )
                    .font(.caption)
                    .foregroundColor(
                        translationService.translationConfidence > 0.7
                            ? .green
                            : translationService.translationConfidence > 0.4 ? .orange : .red
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
            }

            ScrollView {
                HStack {
                    Text(
                        translationService.currentTranslation.isEmpty
                            ? "Ready to translate..." : translationService.currentTranslation
                    )
                    .font(.title2)
                    .foregroundColor(
                        translationService.currentTranslation.isEmpty
                            ? themeManager.colors.secondaryText : themeManager.colors.primaryText
                    )
                    .multilineTextAlignment(.leading)
                    .animation(
                        .easeInOut(duration: 0.3), value: translationService.currentTranslation)

                    Spacer()
                }
            }
            .frame(minHeight: 60)
            .padding()
            .background(themeManager.colors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.colors.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    // MARK: - History Section

    @ViewBuilder
    private var historySection: some View {
        if !translationService.completedSessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Translations")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primaryText)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            Array(translationService.completedSessions.suffix(5).reversed()),
                            id: \.id
                        ) { session in
                            TranslationSessionRow(session: session)
                                .environmentObject(themeManager)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Debug Info Sheet

    @ViewBuilder
    private var debugInfoSheet: some View {
        if showingDebugInfo {
            NavigationView {
                DebugInfoView(
                    debugInfo: debugInfo,
                    translationService: translationService
                )
                .navigationTitle("Debug Info")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingDebugInfo = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Setup and Actions

    private func setupTranslationService() {
        // Setup camera frame processing
        cameraManager.onFrameCaptured = { ciImage in
            print("🎥 [ContentViewEnhanced] Camera frame captured, isTranslating: \(self.isTranslating)")
            if self.isTranslating {
                print("🎥 [ContentViewEnhanced] Processing video frame with EnhancedTranslationService")
                self.translationService.processVideoFrame(ciImage)
            }
        }

        // Setup camera permission callbacks
        cameraManager.onPermissionChanged = { granted in
            DispatchQueue.main.async {
                if !granted {
                    showPermissionAlert = true
                    isTranslating = false
                }
            }
        }

        // Setup translation callbacks
        translationService.onTranslationUpdate = { text, confidence in
            // UI updates are handled by @Published properties
        }

        translationService.onError = { error in
            print("Translation error: \(error)")
        }
    }

    private func toggleTranslation() {
        guard cameraManager.permissionGranted else {
            print("❌ [ContentViewEnhanced] Camera permission not granted")
            showPermissionAlert = true
            return
        }

        isTranslating.toggle()
        print("🔄 [ContentViewEnhanced] Translation toggled - isTranslating: \(isTranslating)")

        if isTranslating {
            print("▶️ [ContentViewEnhanced] Starting translation session and camera")
            translationService.startTranslationSession()
            cameraManager.startSession()
        } else {
            print("⏹️ [ContentViewEnhanced] Stopping translation session")
            translationService.stopTranslationSession()
        }
    }

    private func clearHistory() {
        translationService.resetMetrics()
        // Note: We don't clear completed sessions as they might be valuable
        // In production, you might want to ask for confirmation
    }

    private func startPerformanceMonitoring() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            debugInfo = translationService.getDetailedStatus()
        }
    }

    private func stopPerformanceMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Translation Session Row

struct TranslationSessionRow: View {
    let session: EnhancedTranslationService.TranslationSession
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.translationText)
                    .font(.subheadline)
                    .foregroundColor(themeManager.colors.primaryText)
                    .lineLimit(2)

                HStack {
                    Text(session.displayTime)
                        .font(.caption2)
                        .foregroundColor(themeManager.colors.secondaryText)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(themeManager.colors.secondaryText)

                    Text("\(String(format: "%.0f%%", session.confidence * 100))")
                        .font(.caption2)
                        .foregroundColor(
                            session.confidence > 0.7
                                ? .green : session.confidence > 0.4 ? .orange : .red)
                }
            }

            Spacer()

            Text("\(String(format: "%.1fs", session.duration))")
                .font(.caption2)
                .foregroundColor(themeManager.colors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeManager.colors.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Translation History View

struct TranslationHistoryView: View {
    let sessions: [EnhancedTranslationService.TranslationSession]
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(sessions.reversed()), id: \.id) { session in
                        TranslationHistoryRow(session: session)
                            .environmentObject(themeManager)
                    }
                }
                .padding()
            }
            .navigationTitle("Translation History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TranslationHistoryRow: View {
    let session: EnhancedTranslationService.TranslationSession
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.translationText)
                    .font(.headline)
                    .foregroundColor(themeManager.colors.primaryText)

                Spacer()

                Text("\(String(format: "%.0f%%", session.confidence * 100))")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        session.confidence > 0.7
                            ? Color.green : session.confidence > 0.4 ? Color.orange : Color.red
                    )
                    .cornerRadius(8)
            }

            HStack {
                Text(session.displayTime)
                    .font(.caption)
                    .foregroundColor(themeManager.colors.secondaryText)

                Text("•")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.secondaryText)

                Text("Duration: \(String(format: "%.1fs", session.duration))")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.secondaryText)

                Text("•")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.secondaryText)

                Text("Features: \(session.featuresProcessed)")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.secondaryText)

                Spacer()
            }
        }
        .padding()
        .background(themeManager.colors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.colors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Debug Info View

struct DebugInfoView: View {
    let debugInfo: [String: Any]
    let translationService: EnhancedTranslationService
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Model Status
                debugSection(title: "Model Status") {
                    debugRow(
                        "Model Loaded", value: "\(debugInfo["isModelLoaded"] as? Bool ?? false)")
                    debugRow(
                        "Processing Status",
                        value: debugInfo["processingStatus"] as? String ?? "Unknown")
                    debugRow(
                        "Current Confidence",
                        value: String(
                            format: "%.1f%%", (debugInfo["currentConfidence"] as? Double ?? 0) * 100
                        ))
                }

                // Performance Metrics
                debugSection(title: "Performance") {
                    debugRow(
                        "Frame Rate",
                        value: String(format: "%.1f FPS", debugInfo["frameRate"] as? Double ?? 0))
                    debugRow(
                        "Total Inferences", value: "\(debugInfo["totalInferences"] as? Int ?? 0)")
                    debugRow(
                        "Avg Inference Time",
                        value: String(
                            format: "%.1f ms", debugInfo["averageInferenceTime"] as? Double ?? 0))
                    debugRow(
                        "Success Rate",
                        value: String(
                            format: "%.1f%%", (debugInfo["successRate"] as? Double ?? 0) * 100))
                }

                // Buffer Status
                debugSection(title: "Buffer Status") {
                    debugRow("Buffer Frames", value: "\(debugInfo["bufferFrames"] as? Int ?? 0)")
                    debugRow(
                        "Buffer Features", value: "\(debugInfo["bufferFeatures"] as? Int ?? 0)")
                }

                // Export Button
                Button(action: exportDebugInfo) {
                    Text("Export Debug Info")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.colors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func debugSection<Content: View>(title: String, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(themeManager.colors.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding()
            .background(themeManager.colors.cardBackground)
            .cornerRadius(8)
        }
    }

    private func debugRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(themeManager.colors.secondaryText)

            Spacer()

            Text(value)
                .foregroundColor(themeManager.colors.primaryText)
                .fontWeight(.medium)
        }
    }

    private func exportDebugInfo() {
        let exportData = translationService.exportTranslationHistory()

        // In a real app, you'd implement proper export functionality
        // For now, just print to console
        print("Debug info exported: \(exportData)")

        // You could also copy to clipboard or share via activity sheet
    }
}

// MARK: - Preview

struct ContentViewEnhanced_Previews: PreviewProvider {
    static var previews: some View {
        ContentViewEnhanced()
            .environmentObject(CameraManager())
            .environmentObject(ThemeManager())
    }
}
