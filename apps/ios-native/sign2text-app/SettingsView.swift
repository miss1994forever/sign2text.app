//
//  SettingsView.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var translationService: TranslationService

    @State private var backendURLDraft = ""
    @State private var cameraPosition = "Front"
    @State private var frameRate = 30
    @State private var hapticFeedback = true
    @State private var soundFeedback = false
    @State private var autoSaveTranslations = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Menu {
                            ForEach(ThemeManager.AppTheme.allCases, id: \.self) { theme in
                                Button {
                                    themeManager.setTheme(theme)
                                } label: {
                                    HStack {
                                        Image(systemName: theme.icon)
                                        Text(theme.rawValue)
                                        if themeManager.currentTheme == theme {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: themeManager.currentTheme.icon)
                                Text(themeManager.currentTheme.rawValue)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Choose between light, dark, or system appearance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Translation Model")) {
                    Picker("Recognition Scheme", selection: presetSelection) {
                        ForEach(RecognitionBackendPreset.allCases) { preset in
                            Text(preset.title)
                                .tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(translationService.selectedPreset.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Current Model")
                        Spacer()
                        Text(translationService.currentModel)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        Text(translationService.connectionStatus)
                            .foregroundColor(translationService.lastErrorMessage == nil ? .secondary : .orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backend URL")
                        TextField("http://<your-mac-lan-ip>:6006", text: $backendURLDraft)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .onSubmit {
                                translationService.setBackendURL(backendURLDraft)
                            }

                        Text("Recommended for AutoDL + iPhone: run the backend on AutoDL port 6006, forward it to your Mac with SSH, then fill in your Mac LAN IP here.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Refresh Backend Health") {
                        translationService.setBackendURL(backendURLDraft)
                        translationService.refreshBackendHealth()
                    }

                    if let lastErrorMessage = translationService.lastErrorMessage, !lastErrorMessage.isEmpty {
                        Text(lastErrorMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Section(header: Text("Camera")) {
                    HStack {
                        Text("Camera Position")
                        Spacer()
                        Menu {
                            Button("Front") { cameraPosition = "Front" }
                            Button("Back") { cameraPosition = "Back" }
                        } label: {
                            Text(cameraPosition)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(
                        "Skeleton Overlay",
                        isOn: Binding(
                            get: { translationService.isSkeletonOverlayEnabled },
                            set: { translationService.setSkeletonOverlayEnabled($0) }
                        )
                    )

                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Menu {
                            Button("15 FPS") { frameRate = 15 }
                            Button("24 FPS") { frameRate = 24 }
                            Button("30 FPS") { frameRate = 30 }
                        } label: {
                            Text("\(frameRate) FPS")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Feedback")) {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    Toggle("Sound Feedback", isOn: $soundFeedback)

                    Text("Provide tactile and audio feedback when gestures are recognized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Data")) {
                    Toggle("Auto-save Translations", isOn: $autoSaveTranslations)

                    Button("Clear Translation History") {
                        // Would clear history in a real implementation
                    }
                    .foregroundColor(.red)

                    Button("Clear Dictionary") {
                        // Would clear dictionary in a real implementation
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }

                    Button("Send Feedback") {
                        // Would send feedback in a real implementation
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onAppear {
            backendURLDraft = translationService.backendURL
        }
        .onChange(of: translationService.selectedPreset) { _, _ in
            backendURLDraft = translationService.backendURL
        }
    }

    private var presetSelection: Binding<RecognitionBackendPreset> {
        Binding(
            get: { translationService.selectedPreset },
            set: { translationService.selectPreset($0) }
        )
    }
}

// MARK: - History View
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var translationService: TranslationService

    var body: some View {
        NavigationView {
            List {
                let sessions = translationService.getTranslationHistory()
                
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(themeManager.colors.secondaryText)
                        
                        Text("No translation history")
                            .font(.headline)
                            .foregroundColor(themeManager.colors.primaryText)
                        
                        Text("Start translating to see your history here")
                            .font(.body)
                            .foregroundColor(themeManager.colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        VStack(alignment: .leading, spacing: 8) {
                            // Translation text
                            Text(session.translationText)
                                .font(.body)
                                .foregroundColor(themeManager.colors.primaryText)
                                .lineLimit(nil)
                            
                            // Translation time (absolute time, not relative)
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(themeManager.colors.secondaryText)
                                
                                Text("Started at \(session.displayTime)")
                                    .font(.caption)
                                    .foregroundColor(themeManager.colors.secondaryText)
                                
                                Spacer()
                                
                                if session.isComplete {
                                    Text("Completed")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                // TODO: Implement delete functionality
                            }
                        }
                    }
                }
            }
            .background(themeManager.colors.background)
            .navigationTitle("Translation History")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !translationService.getTranslationHistory().isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            translationService.clearHistory()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

// MARK: - Supporting Types
struct HistoryItem: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
