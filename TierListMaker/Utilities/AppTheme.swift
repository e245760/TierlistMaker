import SwiftUI

// MARK: - AppTheme
//
// アプリ全体の light / dark モードのみを管理する。
// 表ごとのビジュアル（行の背景色・アクセントカラーなど）は TierTheme が担う。

enum AppTheme: String, CaseIterable, Codable {
    case light
    case dark

    // MARK: システムColorSchemeへのマッピング
    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        }
    }

    // MARK: 表示ラベル
    var label: String {
        switch self {
        case .light: return "ライト"
        case .dark:  return "ダーク"
        }
    }

    // MARK: アイコン
    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark:  return "moon.stars"
        }
    }
}

// MARK: - EnvironmentKey

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .light
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - AppStorage RawRepresentable
extension AppTheme: RawRepresentable {}
