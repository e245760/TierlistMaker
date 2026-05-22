import SwiftUI

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Codable {
    case light
    case dark
    // 将来追加例:
    // case ocean
    // case forest

    // MARK: システムColorSchemeへのマッピング
    // カスタムテーマを追加するときも .light か .dark のどちらかをベースにする
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

    // MARK: - アプリ独自カラー
    // カスタムテーマを追加する際はここに case を足していく

    /// プールパネルの背景
    var poolBackground: Color {
        switch self {
        case .light: return Color(.systemBackground)
        case .dark:  return Color(.systemBackground)
        }
    }

    /// フローティングボタンのメインカラー
    var accentColor: Color {
        switch self {
        case .light: return .blue
        case .dark:  return .blue
        }
    }

    /// ティア行のデフォルト背景（アイテムエリア）
    var rowBackground: Color {
        switch self {
        case .light: return Color(.systemGray6)
        case .dark:  return Color(.systemGray6)
        }
    }
}

// MARK: - EnvironmentKey
// テーマを Environment 経由で子Viewに配る準備
// カスタムテーマの独自カラーを使うときは \.appTheme で参照する

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
// @AppStorage で AppTheme を直接保存できるようにする
extension AppTheme: RawRepresentable {}
