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
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var translationService: TranslationService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isTranslating = false
    @State private var currentTranslation = ""  // 当前正在构建的翻译
    @State private var completedTranslations: [String] = []  // 已完成的翻译
    @State private var showingDictionary = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("SignScribe")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.colors.primaryText)

                        Spacer()

                        HStack(spacing: 16) {
                            Button(action: { 
                                print("📈 History button tapped")
                                showingHistory = true 
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3)
                                    .foregroundColor(themeManager.colors.primaryText)
                            }

                            Button(action: { 
                                print("📚 Dictionary button tapped - attempting to show dictionary")
                                do {
                                    showingDictionary = true 
                                    print("📚 Dictionary state set to true")
                                } catch {
                                    print("📚 Error setting dictionary state: \(error)")
                                }
                            }) {
                                Image(systemName: "book.closed")
                                    .font(.title3)
                                    .foregroundColor(themeManager.colors.primaryText)
                            }

                            Button(action: { 
                                print("⚙️ Settings button tapped")
                                showingSettings = true 
                            }) {
                                Image(systemName: "gear")
                                    .font(.title3)
                                    .foregroundColor(themeManager.colors.primaryText)
                            }
                        }
                    }
                    .padding()

                    // Camera Section
                    ZStack {
                        if let previewLayer = cameraManager.previewLayer {
                            CameraPreview(
                                previewLayer: previewLayer
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(
                                Group {
                                    if isTranslating {
                                        VStack {
                                            HStack {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 8, height: 8)
                                                Text("Translating...")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text("FPS: \(Int(cameraManager.currentFrameRate))")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.horizontal)
                                            .padding(.top, 8)
                                            Spacer()
                                        }
                                    }
                                }
                            )
                        } else {
                            // Fallback view if camera isn't ready
                            Rectangle()
                                .fill(themeManager.colors.secondaryBackground)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .overlay(
                                    VStack {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(themeManager.colors.secondaryText)
                                        Text(cameraManager.errorMessage ?? "Camera Ready")
                                            .foregroundColor(themeManager.colors.primaryText)
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
                        setupCameraConnection()
                        cameraManager.checkPermission()
                    }
                    .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
                        Button("Open Settings", role: .none) {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }

                    // Transcription Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Real-time Translation")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.primaryText)

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
                                    // Show completed translations
                                    ForEach(Array(completedTranslations.enumerated()), id: \.offset) { index, text in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("\(index + 1)")
                                                .font(.caption)
                                                .foregroundColor(themeManager.colors.secondaryText)
                                                .frame(width: 20, alignment: .leading)

                                            Text(text)
                                                .font(.body)
                                                .foregroundColor(themeManager.colors.translationText)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 4)
                                        .id("completed-\(index)")
                                    }
                                    
                                    // Show current translation being built
                                    if !currentTranslation.isEmpty {
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(themeManager.colors.accent)
                                                .frame(width: 20, alignment: .leading)

                                            Text(currentTranslation)
                                                .font(.body)
                                                .foregroundColor(themeManager.colors.accent)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 4)
                                        .id("current")
                                    }
                                    
                                    // Show placeholder when not translating
                                    if completedTranslations.isEmpty && currentTranslation.isEmpty {
                                        Text("Start translation to see results here...")
                                            .font(.body)
                                            .foregroundColor(themeManager.colors.secondaryText)
                                            .italic()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                            }
                            .onChange(of: currentTranslation) { oldValue, newValue in
                                if !newValue.isEmpty {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("current", anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: completedTranslations.count) { oldValue, newValue in
                                if newValue > 0 {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        proxy.scrollTo("completed-\(newValue - 1)", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(themeManager.colors.secondaryBackground)
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
                                .foregroundColor(themeManager.colors.secondaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(themeManager.colors.secondaryBackground)
                                .cornerRadius(20)
                            }
                            .disabled(completedTranslations.isEmpty && currentTranslation.isEmpty)

                            Button(action: exportTranscriptions) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export")
                                }
                                .font(.subheadline)
                                .foregroundColor(themeManager.colors.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(themeManager.colors.accent.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .disabled(completedTranslations.isEmpty && currentTranslation.isEmpty)
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
                        themeManager.colors.background.opacity(0.95)
                            .edgesIgnoringSafeArea(.all)

                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(themeManager.colors.primaryText)

                            Text("Camera Permission Required")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.colors.primaryText)
                                .multilineTextAlignment(.center)

                            Text(
                                "SignScribe needs camera access to translate sign language into text in real-time."
                            )
                            .foregroundColor(themeManager.colors.secondaryText)
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
                                    .background(themeManager.colors.accent)
                                    .cornerRadius(10)
                                }

                                Button(action: { cameraManager.checkPermission() }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Try Again")
                                    }
                                    .fontWeight(.medium)
                                    .foregroundColor(themeManager.colors.accent)
                                    .frame(width: 200, height: 50)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(themeManager.colors.accent, lineWidth: 1)
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
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onAppear {
            setupTranslation()
            print("🚀 ContentView appeared")
        }
        .onChange(of: showingDictionary) { oldValue, newValue in
            print("📚 Dictionary sheet state changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: showingSettings) { oldValue, newValue in
            print("⚙️ Settings sheet state changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: showingHistory) { oldValue, newValue in
            print("📈 History sheet state changed: \(oldValue) -> \(newValue)")
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
            HistoryView()
                .environmentObject(themeManager)
                .environmentObject(translationService)
        }
    }

    private func setupCameraConnection() {
        // Connect camera frames to translation service
        cameraManager.onFrameCaptured = { frame in
            if self.isTranslating {
                let _ = self.translationService.processFrame(frame)
            }
        }
    }

    private func setupTranslation() {
        // Setup callback for current translation updates
        translationService.onCurrentTranslationUpdate = { text in
            DispatchQueue.main.async {
                self.currentTranslation = text
            }
        }
        
        // Setup callback for completed translation sessions
        translationService.onTranslationSessionComplete = { session in
            DispatchQueue.main.async {
                self.completedTranslations.append(session.translationText)
                self.currentTranslation = "" // Clear current translation
            }
        }
    }

    private func toggleTranslation() {
        isTranslating.toggle()
        
        if isTranslating {
            cameraManager.startSession()
            translationService.startTranslation()
        } else {
            cameraManager.stopSession()
            translationService.stopTranslation()
        }
    }

    private func clearTranscriptions() {
        completedTranslations.removeAll()
        currentTranslation = ""
        translationService.clearHistory()
    }

    private func exportTranscriptions() {
        var allTranslations = completedTranslations
        if !currentTranslation.isEmpty {
            allTranslations.append(currentTranslation)
        }
        let text = allTranslations.joined(separator: "\n")
        
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
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
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
