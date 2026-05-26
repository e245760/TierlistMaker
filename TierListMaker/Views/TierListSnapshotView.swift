import SwiftUI

/// ティア表全体を ImageRenderer で画像化するための静的ビュー。
///
/// LazyVGrid は ImageRenderer との相性が悪いため、
/// アイテムを手動でチャンクして HStack / VStack でグリッド配置する。
/// このビュー自体はインタラクションを持たず、見た目の再現だけを担う。
///
/// targetHeight が指定された場合、各行の高さをキャンバスを埋めるよう配分する。
/// アイテムが多い行は自然な高さで固定し、残りの余白を他の行に均等分配する。
struct TierListSnapshotView: View {

    let rows: [TierRow]
    let title: String
    let defaultLabelSize: LabelSize
    let defaultLabelTextSize: LabelTextSize
    let defaultItemSize: ItemSize
    let tierTheme: TierTheme
    let canvasWidth: CGFloat
    let targetHeight: CGFloat?

    init(
        rows: [TierRow],
        title: String,
        defaultLabelSize: LabelSize,
        defaultLabelTextSize: LabelTextSize,
        defaultItemSize: ItemSize,
        tierTheme: TierTheme,
        canvasWidth: CGFloat = UIScreen.main.bounds.width,
        targetHeight: CGFloat? = nil
    ) {
        self.rows                 = rows
        self.title                = title
        self.defaultLabelSize     = defaultLabelSize
        self.defaultLabelTextSize = defaultLabelTextSize
        self.defaultItemSize      = defaultItemSize
        self.tierTheme            = tierTheme
        self.canvasWidth          = canvasWidth
        self.targetHeight         = targetHeight
    }

    // MARK: - レイアウト計算

    private var itemAreaWidth: CGFloat {
        canvasWidth - defaultLabelSize.width
    }

    private var itemsPerRow: Int {
        max(1, Int(itemAreaWidth / (defaultItemSize.width + 4)))
    }

    // MARK: - 行高さ配分

    /// ヘッダー部分の概算高さ（subheadline≈15pt + padding×2 + divider1pt）
    private var approximateHeaderHeight: CGFloat { 36 }

    /// 各行に割り当てる高さの辞書。
    ///
    /// アルゴリズム（CSS flex-grow に近い反復法）:
    ///   1. 残り予算を残り行数で均等割り
    ///   2. 自然な高さが均等割りを超える行を「固定」（自然な高さをそのまま使う）
    ///   3. 固定した分を予算から引き、残り行で繰り返す
    ///
    /// これにより「アイテムが多い行は内容に合わせ、空き行が余白を吸収する」動作になる。
    private var rowTargetHeights: [UUID: CGFloat]? {
        guard let total = targetHeight, !rows.isEmpty else { return nil }

        let dividers  = CGFloat(rows.count) * 0.5
        let available = total - approximateHeaderHeight - dividers

        // 各行の自然な高さを計算
        let itemH = defaultItemSize.height
        var naturalDict = [UUID: CGFloat]()
        for row in rows {
            let count  = row.items.count
            let chunks = count == 0 ? 0 : Int(ceil(Double(count) / Double(itemsPerRow)))
            let minH   = itemH + 8
            let h      = chunks == 0 ? minH : max(minH, CGFloat(chunks) * (itemH + 4) + 8)
            naturalDict[row.id] = h
        }

        // 反復配分
        var pendingIds      = Set(rows.map { $0.id })
        var remainingBudget = available
        var result          = [UUID: CGFloat]()

        while !pendingIds.isEmpty {
            let share       = remainingBudget / CGFloat(pendingIds.count)
            let overflowing = pendingIds.filter { naturalDict[$0]! > share }

            if overflowing.isEmpty {
                // 残り全行が均等割り以下 → 均等に分配して終了
                let allocated = max(share, itemH + 8)
                for id in pendingIds { result[id] = allocated }
                break
            }

            // 自然な高さが均等割りを超える行を固定
            for id in overflowing {
                result[id]       = naturalDict[id]!
                remainingBudget -= naturalDict[id]!
                pendingIds.remove(id)
            }
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        // rowTargetHeights は body の外で一度だけ計算
        let heights = rowTargetHeights

        return VStack(spacing: 0) {
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
                rowView(for: row, minHeight: heights?[row.id])
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: canvasWidth, height: 0.5)
            }
        }
        .frame(width: canvasWidth)
        .background(tierTheme.rowBackground)
        // テーマに合わせた colorScheme・tierTheme を子ビューへ配る
        // TierItemView が @Environment(\.tierTheme) でフォントを参照するため必要
        .environment(\.colorScheme, tierTheme.colorScheme)
        .environment(\.tierTheme, tierTheme)
    }

    // MARK: - 行ビュー

    @ViewBuilder
    private func rowView(for row: TierRow, minHeight: CGFloat? = nil) -> some View {
        let chunks   = chunked(row.items, size: itemsPerRow)
        let naturalH = rowHeight(chunkCount: chunks.count)
        let rowH     = max(naturalH, minHeight ?? 0)

        HStack(spacing: 0) {
            // ラベル
            // ← .system(size:weight:) から tierTheme.fontStyle.font(size:) に変更
            Text(row.tierName)
                .font(tierTheme.fontStyle.font(size: defaultLabelTextSize.fontSize))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: defaultLabelSize.width, height: rowH)
                .background(Color(hex: row.color))
                .foregroundColor(Color(hex: row.textColorHex))

            // アイテムグリッド（行の上端から詰めて配置、残りは背景色）
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
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(width: itemAreaWidth, height: rowH, alignment: .topLeading)
            // ── 背景：単色 ＋ 模様を ZStack で重ねる ──
            .background {
                ZStack {
                    tierTheme.rowBackground
                    TierPatternView(
                        pattern: tierTheme.rowPattern,
                        color: tierTheme.patternColor
                    )
                }
            }
        }
        .frame(width: canvasWidth)
    }

    // MARK: - ヘルパー

    private func rowHeight(chunkCount: Int) -> CGFloat {
        let minH = defaultItemSize.height + 8
        guard chunkCount > 0 else { return minH }
        let gridH = CGFloat(chunkCount) * (defaultItemSize.height + 4) + 8
        return max(minH, gridH)
    }

    private func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        guard !array.isEmpty, size > 0 else { return [] }
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0 ..< min($0 + size, array.count)])
        }
    }
}
