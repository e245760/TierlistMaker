import SwiftUI

/// ティア表全体を ImageRenderer で画像化するための静的ビュー。
///
/// LazyVGrid は ImageRenderer との相性が悪いため、
/// アイテムを手動でチャンクして HStack / VStack でグリッド配置する。
/// このビュー自体はインタラクションを持たず、見た目の再現だけを担う。
///
/// targetHeight が指定された場合、各行の高さをキャンバスを埋めるよう均等に引き伸ばす。
/// アイテムサイズ自体は変わらず、アイテム配置エリア（行の高さ）のみが伸びる。
/// コンテンツの自然な高さがキャンバスを超える場合は引き伸ばしを行わない（縮小は呼び出し元が担う）。
struct TierListSnapshotView: View {

    let rows: [TierRow]
    let title: String
    let defaultLabelSize: LabelSize
    let defaultLabelTextSize: LabelTextSize
    let defaultItemSize: ItemSize
    let tierTheme: TierTheme

    /// ImageRenderer に渡す固定幅（デフォルトは端末の画面幅）
    let canvasWidth: CGFloat

    /// 目標キャンバス高さ。指定時は各行をこの高さに収まるよう均等引き伸ばし。
    /// nil のときは自然な高さで描画（従来動作）。
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
        self.rows                = rows
        self.title               = title
        self.defaultLabelSize    = defaultLabelSize
        self.defaultLabelTextSize = defaultLabelTextSize
        self.defaultItemSize     = defaultItemSize
        self.tierTheme           = tierTheme
        self.canvasWidth         = canvasWidth
        self.targetHeight        = targetHeight
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

    // MARK: - 引き伸ばし高さ計算

    /// ヘッダー部分の概算高さ（タイトルテキスト＋上下padding＋区切り線）
    /// subheadline ≈ 15pt、padding 10×2、divider 1pt → 合計 36pt
    private var approximateHeaderHeight: CGFloat { 36 }

    /// 各行に割り当てる最小高さ。
    /// targetHeight が指定されている場合にのみ計算する。
    /// 行の自然な高さがこれを超える場合は自然な高さが優先される。
    private var perRowMinHeight: CGFloat? {
        guard let total = targetHeight, !rows.isEmpty else { return nil }

        // ヘッダー + 各行の下区切り線を引いた残りを行数で均等分割
        let dividers   = CGFloat(rows.count) * 0.5
        let available  = total - approximateHeaderHeight - dividers
        let candidate  = available / CGFloat(rows.count)

        // アイテム1段 + 余白 を下限とする
        let minimum    = defaultItemSize.height + 8
        return max(candidate, minimum)
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
                rowView(for: row, minHeight: perRowMinHeight)
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

    /// - Parameters:
    ///   - minHeight: 行の最小高さ。アイテムの自然な高さより小さい場合は無視される。
    @ViewBuilder
    private func rowView(for row: TierRow, minHeight: CGFloat? = nil) -> some View {
        let chunks   = chunked(row.items, size: itemsPerRow)
        let naturalH = rowHeight(chunkCount: chunks.count)
        // 引き伸ばし：自然な高さと minHeight の大きい方を使う
        let rowH     = max(naturalH, minHeight ?? 0)

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
            // 引き伸ばされた行の上端からアイテムを詰めて配置し、残りは空白になる
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
