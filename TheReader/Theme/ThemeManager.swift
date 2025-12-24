import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @AppStorage("appTheme") private var storedTheme: String = AppTheme.system.rawValue

    @Published var currentTheme: AppTheme = .system {
        didSet {
            storedTheme = currentTheme.rawValue
        }
    }

    init() {
        currentTheme = AppTheme(rawValue: storedTheme) ?? .system
    }

    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var isDark: Bool {
        currentTheme == .dark
    }

    var backgroundColor: Color {
        switch currentTheme {
        case .dark:
            return Color(red: 0.05, green: 0.05, blue: 0.07)
        case .light:
            return Color(red: 0.96, green: 0.96, blue: 0.98)
        case .system:
            return Color(.systemBackground)
        }
    }

    var secondaryBackgroundColor: Color {
        switch currentTheme {
        case .dark:
            return Color(red: 0.1, green: 0.1, blue: 0.12)
        case .light:
            return Color(red: 0.92, green: 0.92, blue: 0.94)
        case .system:
            return Color(.secondarySystemBackground)
        }
    }

    var primaryTextColor: Color {
        switch currentTheme {
        case .dark: return .white
        case .light: return .black
        case .system: return Color(.label)
        }
    }

    var secondaryTextColor: Color {
        switch currentTheme {
        case .dark: return Color(white: 0.7)
        case .light: return Color(white: 0.4)
        case .system: return Color(.secondaryLabel)
        }
    }

    var accentColor: Color {
        Color.blue
    }

    var glassTint: Color {
        switch currentTheme {
        case .dark:
            return Color.white.opacity(0.08)
        case .light:
            return Color.black.opacity(0.04)
        case .system:
            return Color(.systemFill)
        }
    }

    var glassBorder: Color {
        switch currentTheme {
        case .dark:
            return Color.white.opacity(0.15)
        case .light:
            return Color.black.opacity(0.08)
        case .system:
            return Color(.separator)
        }
    }
}
