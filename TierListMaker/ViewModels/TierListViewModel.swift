import SwiftUI
import Combine

@MainActor
class TierListViewModel: ObservableObject {
    @Published var rows: [TierRow] = [
        TierRow(tierName: "S", color: "#FF7F7F", items: []),
        TierRow(tierName: "A", color: "#FFBF7F", items: []),
        TierRow(tierName: "B", color: "#FFFF7F", items: []),
        TierRow(tierName: "C", color: "#7FFF7F", items: []),
        TierRow(tierName: "D", color: "#7FBFFF", items: []),
    ]
    @Published var pool: [TierItem] = []
    @Published var itemAddedCount: Int = 0
    @Published var addedAssetIds: Set<String> = []

    @Published var defaultLabelSize: LabelSize = .square
    @Published var defaultLabelTextSize: LabelTextSize = .medium
    @Published var defaultItemSize: ItemSize = .square
    @Published var defaultItemTextSize: ItemTextSize = .medium
    @Published var tierTheme: TierTheme = .classic

    // MARK: - アイテム追加
    //
    // imageData が渡された場合は ImageFileStore に保存し、
    // TierItem にはファイル名のみを持たせる。

    func addItem(label: String, imageData: Data? = nil) {
        let itemId = UUID()
        var imageFileName: String? = nil

        if let data = imageData {
            let name = ImageFileStore.shared.fileName(for: itemId)
            ImageFileStore.shared.save(data, fileName: name)
            imageFileName = name
        }

        let item = TierItem(
            id: itemId,
            label: label,
            imageFileName: imageFileName,
            itemSize: defaultItemSize,
            textSize: defaultItemTextSize
        )
        pool.append(item)
        itemAddedCount += 1
    }

    func addRow() {
        rows.append(TierRow(tierName: "New", color: nextRowColor()))
    }

    // MARK: - 行追加カラー選択
    //
    // TierRowEditSheet のプリセット8色の中から、
    // 既存行で未使用の色を先頭から順に選ぶ。
    // すべて使用済みの場合は先頭色にフォールバックする。

    private func nextRowColor() -> String {
        let palette = [
            "#FF7F7F", "#FFBF7F", "#FFFF7F", "#7FFF7F",
            "#7FBFFF", "#BF7FFF", "#FF7FBF", "#7FFFFF",
        ]
        let usedColors = Set(rows.map { $0.color.uppercased() })
        let found = palette.first { !usedColors.contains($0.uppercased()) }
        return found ?? palette[0]
    }

    func applyLabelSizeToAll(_ size: LabelSize) {
        defaultLabelSize = size
    }

    func applyLabelTextSizeToAll(_ size: LabelTextSize) {
        defaultLabelTextSize = size
    }

    /// アイテムサイズを一括変更する。
    /// サイズが変わると画像クロップの基準が変わるため、クロップ設定は無条件でリセットする。
    ///
    /// ── @Published 連続発火の抑制 ──
    /// subscript 経由で要素を1件ずつ書き換えると、配列プロパティの willSet（＝
    /// objectWillChange.send()）がアイテム数分だけ呼ばれ、Copy-on-Write の
    /// 配列コピーも繰り返し発生する。
    /// map で新配列をローカル構築してから一括代入することで、
    /// @Published 通知と COW コピーをそれぞれ1回に抑える。
    func applyItemSizeToAll(_ size: ItemSize) {
        defaultItemSize = size

        pool = pool.map { item in
            var i         = item
            i.itemSize    = size
            i.cropOffsetX = 0
            i.cropOffsetY = 0
            i.cropScale   = 1.0
            return i
        }

        rows = rows.map { row in
            var r   = row
            r.items = row.items.map { item in
                var i         = item
                i.itemSize    = size
                i.cropOffsetX = 0
                i.cropOffsetY = 0
                i.cropScale   = 1.0
                return i
            }
            return r
        }
    }

    func applyItemTextSizeToAll(_ size: ItemTextSize) {
        defaultItemTextSize = size

        pool = pool.map { var i = $0; i.textSize = size; return i }

        rows = rows.map { row in
            var r   = row
            r.items = row.items.map { var i = $0; i.textSize = size; return i }
            return r
        }
    }
    
    // MARK: - アイテム解決

    /// item はタップ/ドラッグ開始時点のコピーのため、
    /// IDで pool → rows の順に最新版を探して返す。
    /// 見つからない場合は渡された item をそのまま返す（フォールバック）。
    func resolveLatest(_ item: TierItem) -> TierItem {
        pool.first(where: { $0.id == item.id })
            ?? rows.flatMap(\.items).first(where: { $0.id == item.id })
            ?? item
    }

    func moveItem(_ item: TierItem, toRowId rowId: UUID) {
        let current = resolveLatest(item)

        // pool にある場合
        if let poolIdx = poolIndex(for: current.id) {
            pool.remove(at: poolIdx)
            if let rowIdx = rows.firstIndex(where: { $0.id == rowId }) {
                rows[rowIdx].items.append(current)
            }
            return
        }

        // 別の行にある場合
        if let srcRowIdx = rowIndex(for: current.id),
            let itemIdx   = itemIndex(for: current.id, in: srcRowIdx) {
            // 移動元と移動先が同じ行なら何もしない
            guard rows[srcRowIdx].id != rowId else { return }
            rows[srcRowIdx].items.remove(at: itemIdx)
            if let dstRowIdx = rows.firstIndex(where: { $0.id == rowId }) {
                rows[dstRowIdx].items.append(current)
            }
        }
    }

    func returnToPool(_ item: TierItem) {
        let current = resolveLatest(item)

        // 既に pool にある場合は何もしない
        guard poolIndex(for: current.id) == nil else { return }

        // 行から取り出して pool へ
        if let rowIdx  = rowIndex(for: current.id),
            let itemIdx = itemIndex(for: current.id, in: rowIdx) {
            rows[rowIdx].items.remove(at: itemIdx)
            pool.append(current)
        }
    }

    func removeRow(id: UUID) {
        if let idx = rows.firstIndex(where: { $0.id == id }) {
            pool.append(contentsOf: rows[idx].items)
            rows.remove(at: idx)
        }
    }

    /// 行を別の位置に移動する。
    /// fromId の行を toId の行の位置まで移動し、それ以外の行の順序は維持する。
    func moveRow(fromId: UUID, toId: UUID) {
        guard
            let fromIdx = rows.firstIndex(where: { $0.id == fromId }),
            let toIdx   = rows.firstIndex(where: { $0.id == toId }),
            fromIdx != toIdx
        else { return }
        rows.move(
            fromOffsets: IndexSet(integer: fromIdx),
            toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
        )
    }

    func rowIndex(for itemId: UUID) -> Int? {
        rows.firstIndex(where: { $0.items.contains(where: { $0.id == itemId }) })
    }

    func itemIndex(for itemId: UUID, in rowIdx: Int) -> Int? {
        rows[rowIdx].items.firstIndex(where: { $0.id == itemId })
    }

    func poolIndex(for itemId: UUID) -> Int? {
        pool.firstIndex(where: { $0.id == itemId })
    }

    // MARK: - 保存・読み込み

    func toSaveData(id: UUID, title: String, createdAt: Date = Date()) -> TierListSaveData {
        TierListSaveData(
            id: id,
            title: title,
            rows: rows,
            pool: pool,
            defaultLabelSize: defaultLabelSize,
            defaultLabelTextSize: defaultLabelTextSize,
            defaultItemSize: defaultItemSize,
            defaultItemTextSize: defaultItemTextSize,
            tierTheme: tierTheme,
            addedAssetIds: addedAssetIds,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    func load(from data: TierListSaveData) {
        rows                 = data.rows
        pool                 = data.pool
        defaultLabelSize     = data.defaultLabelSize
        defaultLabelTextSize = data.defaultLabelTextSize
        defaultItemSize      = data.defaultItemSize
        defaultItemTextSize  = data.defaultItemTextSize
        tierTheme            = data.tierTheme
        addedAssetIds        = data.addedAssetIds
    }
}
