import SwiftUI

// MARK: - TierTheme
//
// 表ごとのビジュアルテーマ。AppTheme（アプリ全体のlight/dark）とは完全に独立。
//
// ── テーマを追加するには ──
//   1. enum に case を追加する（例: case ocean = "ocean"）
//   2. isPro に case を追加して無料/Pro を設定する
//   3. 下記の各プロパティに case を追加して色・フォント・模様を定義する
//   4. TableEditSheet の ForEach が自動で新しい選択肢を表示する（allCases のため）
//
//   それ以外のファイルは一切触らなくてよい。

enum TierTheme: String, CaseIterable, Codable {
    case classic = "classic"
    case dark    = "dark"
    case ocean   = "ocean"   // Pro限定
    case sunset  = "sunset"  // Pro限定
    case forest  = "forest"  // Pro限定

    // MARK: - Pro限定フラグ

    /// true のテーマは PurchaseManager.isPro が false のとき選択不可
    var isPro: Bool {
        switch self {
        case .classic, .dark:          return false
        case .ocean, .sunset, .forest: return true
        }
    }

    // MARK: - UI表示

    var displayName: String {
        switch self {
        case .classic: return "クラシック"
        case .dark:    return "ダーク"
        case .ocean:   return "オーシャン"
        case .sunset:  return "サンセット"
        case .forest:  return "フォレスト"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "sun.max"
        case .dark:    return "moon.stars"
        case .ocean:   return "water.waves"
        case .sunset:  return "sunset.fill"
        case .forest:  return "leaf.fill"
        }
    }

    // MARK: - ColorScheme
    // テーマが要求する light / dark モード

    var colorScheme: ColorScheme {
        switch self {
        case .classic, .ocean, .sunset, .forest: return .light
        case .dark:                              return .dark
        }
    }

    // MARK: - 背景色

    /// ティア行のアイテムエリア背景
    var rowBackground: Color {
        switch self {
        case .classic: return Color(.systemGray6)
        case .dark:    return Color(.systemGray6)
        case .ocean:   return Color(hex: "#DDF0FB")
        case .sunset:  return Color(hex: "#FFF0E6")
        case .forest:  return Color(hex: "#E4F4E2")
        }
    }

    /// 未分類プールパネルの背景
    var poolBackground: Color {
        switch self {
        case .classic: return Color(.systemBackground)
        case .dark:    return Color(.systemBackground)
        case .ocean:   return Color(hex: "#F0F8FF")
        case .sunset:  return Color(hex: "#FFF8F2")
        case .forest:  return Color(hex: "#F2FAF1")
        }
    }

    /// フローティングボタン・アクセントのメインカラー
    var accentColor: Color {
        switch self {
        case .classic: return .blue
        case .dark:    return .blue
        case .ocean:   return Color(hex: "#0077B6")
        case .sunset:  return Color(hex: "#E8600A")
        case .forest:  return Color(hex: "#2D6A2D")
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
        case .ocean:   return .rounded
        case .sunset:  return .rounded
        case .forest:  return .serif
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
        case .ocean:   return .dots
        case .sunset:  return .none
        case .forest:  return .stripe
        }
    }

    /// 模様の描画色（rowBackground に対して見える程度の不透明度で指定する）
    var patternColor: Color {
        switch self {
        case .classic: return Color(.label).opacity(0.06)
        case .dark:    return Color(.label).opacity(0.06)
        case .ocean:   return Color(hex: "#0077B6").opacity(0.10)
        case .sunset:  return Color(hex: "#E8600A").opacity(0.07)
        case .forest:  return Color(hex: "#2D6A2D").opacity(0.10)
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
