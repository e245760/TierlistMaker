import SwiftUI
import Combine

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
        rows.append(TierRow(tierName: "New", color: "#AAAAAA"))
    }

    func applyLabelSizeToAll(_ size: LabelSize) {
        defaultLabelSize = size
    }

    func applyLabelTextSizeToAll(_ size: LabelTextSize) {
        defaultLabelTextSize = size
    }

    /// アイテムサイズを一括変更する。
    /// サイズが変わると画像クロップの基準が変わるため、クロップ設定は無条件でリセットする。
    func applyItemSizeToAll(_ size: ItemSize) {
        defaultItemSize = size
        for i in pool.indices {
            pool[i].itemSize    = size
            pool[i].cropOffsetX = 0
            pool[i].cropOffsetY = 0
            pool[i].cropScale   = 1.0
        }
        for i in rows.indices {
            for j in rows[i].items.indices {
                rows[i].items[j].itemSize    = size
                rows[i].items[j].cropOffsetX = 0
                rows[i].items[j].cropOffsetY = 0
                rows[i].items[j].cropScale   = 1.0
            }
        }
    }

    func applyItemTextSizeToAll(_ size: ItemTextSize) {
        defaultItemTextSize = size
        for i in pool.indices { pool[i].textSize = size }
        for i in rows.indices {
            for j in rows[i].items.indices { rows[i].items[j].textSize = size }
        }
    }

    func moveItem(_ item: TierItem, toRowId rowId: UUID) {
        // selectedItem は選択時点のコピーなので、IDで最新版を解決してから移動する
        let current = pool.first(where: { $0.id == item.id })
            ?? rows.flatMap(\.items).first(where: { $0.id == item.id })
            ?? item
        pool.removeAll { $0.id == item.id }
        for i in rows.indices { rows[i].items.removeAll { $0.id == item.id } }
        if let idx = rows.firstIndex(where: { $0.id == rowId }) {
            rows[idx].items.append(current)
        }
    }

    func returnToPool(_ item: TierItem) {
        // 同様にIDで最新版を解決してからプールに戻す
        let current = pool.first(where: { $0.id == item.id })
            ?? rows.flatMap(\.items).first(where: { $0.id == item.id })
            ?? item
        for i in rows.indices { rows[i].items.removeAll { $0.id == item.id } }
        if !pool.contains(where: { $0.id == item.id }) { pool.append(current) }
    }

    func removeRow(id: UUID) {
        if let idx = rows.firstIndex(where: { $0.id == id }) {
            pool.append(contentsOf: rows[idx].items)
            rows.remove(at: idx)
        }
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
    }
}
