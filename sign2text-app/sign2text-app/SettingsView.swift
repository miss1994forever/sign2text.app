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

    @State private var selectedModelType = "Dummy"
    @State private var cameraPosition = "Front"
    @State private var frameRate = 30
    @State private var hapticFeedback = true
    @State private var soundFeedback = false
    @State private var autoSaveTranslations = true

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Translation Model")) {
                    HStack {
                        Text("Current Model")
                        Spacer()
                        Menu {
                            Button("Dummy Model") { selectedModelType = "Dummy" }
                            Button("CV-SLT Model") { selectedModelType = "CV-SLT" }
                        } label: {
                            Text(selectedModelType)
                                .foregroundColor(.secondary)
                        }
                    }

                    if selectedModelType == "CV-SLT" {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Not Loaded")
                                .foregroundColor(.orange)
                        }
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
    }
}

// MARK: - History View
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var translations = [
        HistoryItem(text: "你好", timestamp: Date()),
        HistoryItem(text: "谢谢", timestamp: Date().addingTimeInterval(-300)),
        HistoryItem(text: "再见", timestamp: Date().addingTimeInterval(-600)),
    ]

    var body: some View {
        NavigationView {
            List {
                if translations.isEmpty {
                    Text("No translation history")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(translations) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .font(.headline)

                            Text(item.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Translation History")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        translations.removeAll()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(translations.isEmpty)
                }
            }
        }
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
