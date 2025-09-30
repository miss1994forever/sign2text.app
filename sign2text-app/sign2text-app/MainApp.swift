//
//  MainApp.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

// Import the required components
import SwiftUI

/// The main entry point for the SignScribe application
@main
struct SignScribeApp: App {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var translationService = TranslationService() // Keep for compatibility with SettingsView
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentViewEnhanced()
                .environmentObject(cameraManager)
                .environmentObject(translationService)
                .environmentObject(themeManager)
        }
    }
}
