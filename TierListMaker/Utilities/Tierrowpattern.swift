import SwiftUI

// MARK: - TierRowPattern
//
// アイテムエリアの背景に重ねる模様を定義する。
// Canvas で描画するため、追加のリソースは不要。
//
// ── 模様を追加するには ──
//   1. enum に case を追加する
//   2. displayName / icon / draw(in:color:) に case を追加する
//   それ以外のファイルは触らなくてよい。

enum TierRowPattern: String, CaseIterable, Codable {
    case none      = "none"
    case stripe    = "stripe"
    case grid      = "grid"
    case dots      = "dots"
    case diagonal  = "diagonal"

    // MARK: - 表示名

    var displayName: String {
        switch self {
        case .none:     return "なし"
        case .stripe:   return "ストライプ"
        case .grid:     return "格子"
        case .dots:     return "ドット"
        case .diagonal: return "斜線"
        }
    }

    var icon: String {
        switch self {
        case .none:     return "square"
        case .stripe:   return "line.3.horizontal"
        case .grid:     return "grid"
        case .dots:     return "circle.grid.3x3"
        case .diagonal: return "line.diagonal"
        }
    }

    // MARK: - Canvas 描画
    //
    // color は TierTheme.patternColor から渡される。
    // 模様は背景色（rowBackground）の上に重ねて描画する。

    func draw(in context: GraphicsContext, size: CGSize, color: Color) {
        switch self {
        case .none:
            break

        case .stripe:
            // 横ストライプ（間隔 10pt、線幅 1pt）
            let spacing: CGFloat = 10
            var y: CGFloat = spacing / 2
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 1)
                y += spacing
            }

        case .grid:
            // 縦横格子（間隔 14pt、線幅 0.6pt）
            let spacing: CGFloat = 14
            var x: CGFloat = spacing / 2
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 0.6)
                x += spacing
            }
            var y: CGFloat = spacing / 2
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(color), lineWidth: 0.6)
                y += spacing
            }

        case .dots:
            // ドット格子（間隔 12pt、半径 1.2pt）
            let spacing: CGFloat = 12
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(
                        x: x - 1.2, y: y - 1.2,
                        width: 2.4, height: 2.4
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    y += spacing
                }
                x += spacing
            }

        case .diagonal:
            // 右下がり斜線（間隔 14pt、線幅 1pt）
            let spacing: CGFloat = 14
            let total = size.width + size.height
            var offset: CGFloat = -size.height
            while offset < total {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 1)
                offset += spacing
            }
        }
    }
}

// MARK: - TierPatternView
//
// TierRowPattern を Canvas でレンダリングするビュー。
// TierRowView と TierListSnapshotView の背景に ZStack で重ねて使う。
// allowsHitTesting(false) でタップイベントを透過させる。

struct TierPatternView: View {
    let pattern: TierRowPattern
    let color: Color

    var body: some View {
        Canvas { context, size in
            pattern.draw(in: context, size: size, color: color)
        }
        .allowsHitTesting(false)
    }
}
