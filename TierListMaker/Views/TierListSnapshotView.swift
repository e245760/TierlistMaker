import SwiftUI

/// ティア表全体を ImageRenderer で画像化するための静的ビュー。
///
/// LazyVGrid は ImageRenderer との相性が悪いため、
/// アイテムを手動でチャンクして HStack / VStack でグリッド配置する。
/// このビュー自体はインタラクションを持たず、見た目の再現だけを担う。
struct TierListSnapshotView: View {

    let rows: [TierRow]
    let title: String
    let defaultLabelSize: LabelSize
    let defaultLabelTextSize: LabelTextSize
    let defaultItemSize: ItemSize
    let tierTheme: TierTheme

    /// ImageRenderer に渡す固定幅（デフォルトは端末の画面幅）
    let canvasWidth: CGFloat

    init(
        rows: [TierRow],
        title: String,
        defaultLabelSize: LabelSize,
        defaultLabelTextSize: LabelTextSize,
        defaultItemSize: ItemSize,
        tierTheme: TierTheme,
        canvasWidth: CGFloat = UIScreen.main.bounds.width
    ) {
        self.rows                = rows
        self.title               = title
        self.defaultLabelSize    = defaultLabelSize
        self.defaultLabelTextSize = defaultLabelTextSize
        self.defaultItemSize     = defaultItemSize
        self.tierTheme           = tierTheme
        self.canvasWidth         = canvasWidth
    }

    // MARK: - レイアウト計算

    /// ラベル列を除いたアイテムエリアの幅
    private var itemAreaWidth: CGFloat {
        canvasWidth - defaultLabelSize.width
    }

    /// アイテムエリアに横並びできる最大個数
    private var itemsPerRow: Int {
        max(1, Int(itemAreaWidth / (defaultItemSize.width + 4)))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // タイトルヘッダー
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .padding(.vertical, 10)
                .frame(width: canvasWidth)
                .background(Color(.systemGray5))

            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: canvasWidth, height: 1)

            // ティア行
            ForEach(rows) { row in
                rowView(for: row)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: canvasWidth, height: 0.5)
            }
        }
        .frame(width: canvasWidth)
        .background(tierTheme.rowBackground)
        // テーマに合わせた colorScheme を適用（TierItemView / 背景色に効く）
        .environment(\.colorScheme, tierTheme.colorScheme)
    }

    // MARK: - 行ビュー

    @ViewBuilder
    private func rowView(for row: TierRow) -> some View {
        let chunks = chunked(row.items, size: itemsPerRow)
        let rowH   = rowHeight(chunkCount: chunks.count)

        HStack(spacing: 0) {
            // ラベル
            Text(row.tierName)
                .font(.system(size: defaultLabelTextSize.fontSize, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: defaultLabelSize.width, height: rowH)
                .background(Color(hex: row.color))
                .foregroundColor(Color(hex: row.textColorHex))

            // アイテムグリッド（非 Lazy）
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                    HStack(spacing: 4) {
                        ForEach(chunk) { item in
                            TierItemView(item: item)
                                .frame(
                                    width:  defaultItemSize.width,
                                    height: defaultItemSize.height
                                )
                        }
                    }
                }
            }
            .padding(4)
            .frame(width: itemAreaWidth, height: rowH, alignment: .topLeading)
            .background(tierTheme.rowBackground)
        }
        .frame(width: canvasWidth)
    }

    // MARK: - ヘルパー

    /// 行の高さ：チャンク数から算出し、最低でも itemSize の高さ＋余白を確保する
    private func rowHeight(chunkCount: Int) -> CGFloat {
        let minH = defaultItemSize.height + 8
        guard chunkCount > 0 else { return minH }
        let gridH = CGFloat(chunkCount) * (defaultItemSize.height + 4) + 8
        return max(minH, gridH)
    }

    /// 配列を指定サイズで分割する
    private func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        guard !array.isEmpty, size > 0 else { return [] }
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0 ..< min($0 + size, array.count)])
        }
    }
}
