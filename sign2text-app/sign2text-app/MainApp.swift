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
    @StateObject private var translationService = TranslationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraManager)
                .environmentObject(translationService)
        }
    }
}
