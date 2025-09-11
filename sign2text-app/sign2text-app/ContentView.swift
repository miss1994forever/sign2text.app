//
//  ContentView.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import AVFoundation

import SwiftUI


#if canImport(UIKit)
    import UIKit
#endif

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @EnvironmentObject private var translationService: TranslationService

    @State private var isTranslating = false
    @State private var transcriptions: [String] = []
    @State private var showingDictionary = false
    @State private var showingSettings = false
    @State private var showingHistory = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("SignScribe")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        HStack(spacing: 16) {
                            Button(action: { showingHistory = true }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }

                            Button(action: { showingDictionary = true }) {
                                Image(systemName: "book.closed")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }

                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gear")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding()

                    // Camera Section
                    ZStack {
                        // Check if the previewLayer is available from the cameraManager
                        if let previewLayer = cameraManager.previewLayer {
                            CameraPreview(
                                previewLayer: previewLayer
                            )
                            .frame(height: 350)
                            // Add an overlay for status indicators like "Translating..." and FPS
                            .overlay(
                                CameraOverlay(
                                    isTranslating: isTranslating,
                                    isRecording: isTranslating, // You can link this to a different state if needed
                                    frameCount: cameraManager.frameCount,
                                    fps: cameraManager.currentFrameRate
                                )
                            )
                        } else {
                            // Fallback view if camera isn't ready
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 350)
                                .overlay(
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(cameraManager.errorMessage ?? "Camera Ready")
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                )
                        }
                    }
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .onAppear {
                        // Start the camera session when the view appears
                        cameraManager.startSession()
                    }
                    .onDisappear {
                        // Stop the camera session when the view disappears to save battery
                        cameraManager.stopSession()
                    }

                    // Transcription Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Real-time Translation")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            if isTranslating {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    if transcriptions.isEmpty {
                                        Text("Start translation to see results here...")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    } else {
                                        ForEach(Array(transcriptions.enumerated()), id: \.offset) {
                                            index, text in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("\(index + 1)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 20, alignment: .leading)

                                                Text(text)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.vertical, 4)
                                            .id(index)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }
                            .onChange(of: transcriptions.count) { oldValue, newValue in
                                if !transcriptions.isEmpty {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        proxy.scrollTo(transcriptions.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .frame(height: 150)
                    .padding(.horizontal)

                    // Control Section
                    VStack(spacing: 16) {
                        Button(action: toggleTranslation) {
                            HStack(spacing: 12) {
                                Image(systemName: isTranslating ? "stop.fill" : "play.fill")
                                    .font(.title3)
                                Text(isTranslating ? "Stop Translation" : "Start Translation")
                                    .font(.headline)
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 240, height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: isTranslating
                                            ? [Color.red.opacity(0.8), Color.red]
                                            : [Color.green.opacity(0.8), Color.green]
                                    ),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                            .shadow(
                                color: (isTranslating ? Color.red : Color.green).opacity(0.3),
                                radius: 8, x: 0, y: 4
                            )
                            .scaleEffect(isTranslating ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isTranslating)
                        }

                        HStack(spacing: 20) {
                            Button(action: clearTranscriptions) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Clear")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(20)
                            }
                            .disabled(transcriptions.isEmpty)

                            Button(action: exportTranscriptions) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .disabled(transcriptions.isEmpty)
                        }

                        Text("Camera ready • Model: Demo Mode")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }

                if !cameraManager.permissionGranted {
                    ZStack {
                        Color.black.opacity(0.85)
                            .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)

                            Text("Camera Permission Required")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text(
                                "SignScribe needs camera access to translate sign language into text in real-time."
                            )
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                            VStack(spacing: 12) {
                                Button(action: openSettings) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }

                                Button(action: { cameraManager.checkPermission() }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Try Again")
                                    }
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .frame(width: 200, height: 50)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.top, 10)
                        }
                        .padding()
                    }
                }
            }
        }
        #if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
        #endif
        .onAppear {
            setupTranslation()
        }
        .sheet(isPresented: $showingDictionary) {
            DictionaryPlaceholderView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsPlaceholderView()
        }
        .sheet(isPresented: $showingHistory) {
            HistoryPlaceholderView()
        }
    }

    private func setupTranslation() {
        translationService.onTranslationUpdate = { text in
            DispatchQueue.main.async {
                transcriptions.append(text)
            }
        }
    }

    private func toggleTranslation() {
        isTranslating.toggle()

        if isTranslating {
            translationService.startTranslation()
        } else {
            translationService.stopTranslation()
        }
    }

    private func clearTranscriptions() {
        transcriptions.removeAll()
    }

    private func exportTranscriptions() {
        let text = transcriptions.joined(separator: "\n")
        #if canImport(UIKit)
            let activityVC = UIActivityViewController(
                activityItems: [text], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let window = windowScene.windows.first
            {
                window.rootViewController?.present(activityVC, animated: true)
            }
        #endif
    }

    private func openSettings() {
        #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        #endif
    }
}

// MARK: - Supporting Classes

// MARK: - Placeholder Views

struct DictionaryPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "book.closed")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)

                Text("Dictionary")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Upload photos of new sign language words to build your custom dictionary.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Text("Feature Coming Soon")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding()
            .navigationTitle("Dictionary")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Translation Model")) {
                    HStack {
                        Text("Current Model")
                        Spacer()
                        Text("Demo Mode")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Camera")) {
                    HStack {
                        Text("Camera Position")
                        Spacer()
                        Text("Front")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Text("30 FPS")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HistoryPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)

                Text("Translation History")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your translation history will appear here after you start using the app.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
