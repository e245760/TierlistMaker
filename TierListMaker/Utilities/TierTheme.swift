import SwiftUI

// MARK: - TierTheme
//
// 表ごとのビジュアルテーマ。AppTheme（アプリ全体のlight/dark）とは完全に独立。
//
// ── テーマを追加するには ──
//   1. enum に case を追加する（例: case ocean = "ocean"）
//   2. 下記の各プロパティに case を追加して色・フォント・模様を定義する
//   3. TableEditSheet の ForEach が自動で新しい選択肢を表示する（allCases のため）
//
//   それ以外のファイルは一切触らなくてよい。

enum TierTheme: String, CaseIterable, Codable {
    case classic = "classic"
    case dark    = "dark"
    // ── 追加例（コメントを外してプロパティに case を足すだけ）──
    // case ocean  = "ocean"
    // case forest = "forest"
    // case sakura = "sakura"

    // MARK: - UI表示

    var displayName: String {
        switch self {
        case .classic: return "クラシック"
        case .dark:    return "ダーク"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "sun.max"
        case .dark:    return "moon.stars"
        }
    }

    // MARK: - ColorScheme
    // テーマが要求する light / dark モード

    var colorScheme: ColorScheme {
        switch self {
        case .classic: return .light
        case .dark:    return .dark
        }
    }

    // MARK: - 背景色

    /// ティア行のアイテムエリア背景
    var rowBackground: Color {
        switch self {
        case .classic: return Color(.systemGray6)
        case .dark:    return Color(.systemGray6)
        }
    }

    /// 未分類プールパネルの背景
    var poolBackground: Color {
        switch self {
        case .classic: return Color(.systemBackground)
        case .dark:    return Color(.systemBackground)
        }
    }

    /// フローティングボタン・アクセントのメインカラー
    var accentColor: Color {
        switch self {
        case .classic: return .blue
        case .dark:    return .blue
        }
    }

    // MARK: - フォント
    //
    // ラベルテキスト・テキストアイテムに適用するフォントスタイル。
    // TierFontStyle.font(size:) を呼び出して Font を生成する。

    var fontStyle: TierFontStyle {
        switch self {
        case .classic: return .system
        case .dark:    return .system
        // case .ocean:   return .rounded
        // case .forest:  return .serif
        // case .sakura:  return .rounded
        }
    }

    // MARK: - 背景模様
    //
    // アイテムエリア背景（rowBackground）に重ねて描画する模様。
    // TierPatternView がこの値を使って Canvas レンダリングする。

    var rowPattern: TierRowPattern {
        switch self {
        case .classic: return .none
        case .dark:    return .none
        // case .ocean:   return .dots
        // case .forest:  return .stripe
        // case .sakura:  return .diagonal
        }
    }

    /// 模様の描画色（rowBackground に対して見える程度の不透明度で指定する）
    var patternColor: Color {
        switch self {
        case .classic: return Color(.label).opacity(0.06)
        case .dark:    return Color(.label).opacity(0.06)
        // case .ocean:   return Color(hex: "#FFFFFF").opacity(0.07)
        // case .forest:  return Color(hex: "#FFFFFF").opacity(0.08)
        // case .sakura:  return Color(hex: "#FF2D55").opacity(0.08)
        }
    }
}

// MARK: - EnvironmentKey

private struct TierThemeKey: EnvironmentKey {
    static let defaultValue: TierTheme = .classic
}

extension EnvironmentValues {
    var tierTheme: TierTheme {
        get { self[TierThemeKey.self] }
        set { self[TierThemeKey.self] = newValue }
    }
}
