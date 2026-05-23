import SwiftUI

// MARK: - TierTheme
//
// 表ごとのビジュアルテーマ。AppTheme（アプリ全体のlight/dark）とは完全に独立。
//
// ── テーマを追加するには ──
//   1. enum に case を追加する（例: case ocean = "ocean"）
//   2. 下記の各プロパティに case を追加して色・外観を定義する
//   3. TableEditSheet の ForEach が自動で新しい選択肢を表示する（allCases のため）
//
// それ以外のファイルは一切触らなくてよい。

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
        // case .ocean:   return "オーシャン"
        // case .forest:  return "フォレスト"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "sun.max"
        case .dark:    return "moon.stars"
        // case .ocean:   return "water.waves"
        // case .forest:  return "leaf"
        }
    }

    // MARK: - ColorScheme
    // テーマが要求する light / dark モード
    // カスタムテーマは .light か .dark のどちらかをベースにする

    var colorScheme: ColorScheme {
        switch self {
        case .classic: return .light
        case .dark:    return .dark
        // case .ocean:   return .dark
        // case .forest:  return .light
        }
    }

    // MARK: - 表のビジュアルカラー
    // ここにテーマ固有の色を定義する。
    // システムカラー（Color(.systemGray6) など）はcolorSchemeに追従するため、
    // light/dark の切り替えだけなら systemColor で十分。
    // 独自の色を使いたい場合は Color(hex: "...") で直接指定する。

    /// ティア行のアイテムエリア背景
    var rowBackground: Color {
        switch self {
        case .classic: return Color(.systemGray6)
        case .dark:    return Color(.systemGray6)
        // case .ocean:   return Color(hex: "#0D2137")
        // case .forest:  return Color(hex: "#1E2D1F")
        }
    }

    /// 未分類プールパネルの背景
    var poolBackground: Color {
        switch self {
        case .classic: return Color(.systemBackground)
        case .dark:    return Color(.systemBackground)
        // case .ocean:   return Color(hex: "#0A1929")
        // case .forest:  return Color(hex: "#131A14")
        }
    }

    /// フローティングボタン・アクセントのメインカラー
    var accentColor: Color {
        switch self {
        case .classic: return .blue
        case .dark:    return .blue
        // case .ocean:   return Color(hex: "#00B4D8")
        // case .forest:  return Color(hex: "#52B788")
        }
    }
}

// MARK: - EnvironmentKey
// 表テーマを Environment 経由で子Viewに配る
// TierRowView・ItemPoolView などで @Environment(\.tierTheme) として参照する

private struct TierThemeKey: EnvironmentKey {
    static let defaultValue: TierTheme = .classic
}

extension EnvironmentValues {
    var tierTheme: TierTheme {
        get { self[TierThemeKey.self] }
        set { self[TierThemeKey.self] = newValue }
    }
}
