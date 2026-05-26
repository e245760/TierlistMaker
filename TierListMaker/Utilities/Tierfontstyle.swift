import SwiftUI

// MARK: - TierFontStyle
//
// テーマごとのフォントスタイルを定義する。
// カスタムフォントを埋め込む場合は .custom case を追加し、
// font(size:) の中で Font.custom(...) を返す形に拡張できる。
//
// 現在はすべて iOS 標準フォントデザインを使用しているため、
// フォントファイルの埋め込みは不要。

enum TierFontStyle: String, CaseIterable, Codable {
    case system     = "system"      // デフォルト（SF Pro）
    case rounded    = "rounded"     // SF Rounded（丸ゴシック風）
    case serif      = "serif"       // SF Serif（明朝体風）
    case monospaced = "monospaced"  // SF Monospaced（等幅）

    // MARK: - 表示名

    var displayName: String {
        switch self {
        case .system:     return "デフォルト"
        case .rounded:    return "丸ゴシック"
        case .serif:      return "明朝体"
        case .monospaced: return "等幅"
        }
    }

    var icon: String {
        switch self {
        case .system:     return "textformat"
        case .rounded:    return "textformat.alt"
        case .serif:      return "textformat.abc"
        case .monospaced: return "textformat.abc.dottedunderline"
        }
    }

    // MARK: - Font 生成
    //
    // テーマに適用するフォントは常に Bold。
    // minimumScaleFactor を使っているため size はそのまま渡す。

    func font(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: .bold)
        case .rounded:
            return .system(size: size, weight: .bold, design: .rounded)
        case .serif:
            return .system(size: size, weight: .bold, design: .serif)
        case .monospaced:
            return .system(size: size, weight: .bold, design: .monospaced)
        }
    }
}
