//
//  ThemeManager.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import SwiftUI

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .light
    
    enum AppTheme: String, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
        
        var colorScheme: ColorScheme? {
            switch self {
            case .light:
                return .light
            case .dark:
                return .dark
            case .system:
                return nil
            }
        }
        
        var icon: String {
            switch self {
            case .light:
                return "sun.max"
            case .dark:
                return "moon"
            case .system:
                return "circle.lefthalf.filled"
            }
        }
    }
    
    // 主题颜色配置
    struct Colors {
        let background: Color
        let secondaryBackground: Color
        let cardBackground: Color
        let primaryText: Color
        let secondaryText: Color
        let accent: Color
        let border: Color
        let shadow: Color
        let translationText: Color // 专门用于翻译文本的颜色
    }
    
    var colors: Colors {
        switch currentTheme {
        case .light:
            return Colors(
                background: Color.white,
                secondaryBackground: Color.gray.opacity(0.05),
                cardBackground: Color.white,
                primaryText: Color.black,
                secondaryText: Color.gray,
                accent: Color.blue,
                border: Color.gray.opacity(0.3),
                shadow: Color.black.opacity(0.1),
                translationText: Color.black // 浅色模式下翻译文本使用黑色
            )
        case .dark:
            return Colors(
                background: Color.black,
                secondaryBackground: Color.gray.opacity(0.1),
                cardBackground: Color.gray.opacity(0.2),
                primaryText: Color.white,
                secondaryText: Color.gray.opacity(0.7),
                accent: Color.blue,
                border: Color.gray.opacity(0.3),
                shadow: Color.clear,
                translationText: Color.white // 深色模式下翻译文本使用白色
            )
        case .system:
            return Colors(
                background: Color(.systemBackground),
                secondaryBackground: Color(.secondarySystemBackground),
                cardBackground: Color(.systemBackground),
                primaryText: Color(.label),
                secondaryText: Color(.secondaryLabel),
                accent: Color.accentColor,
                border: Color(.separator),
                shadow: Color.black.opacity(0.1),
                translationText: Color(.label) // 系统模式下跟随系统标签颜色
            )
        }
    }
    
    func toggleTheme() {
        switch currentTheme {
        case .light:
            currentTheme = .dark
        case .dark:
            currentTheme = .system
        case .system:
            currentTheme = .light
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}
