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

    // デフォルト値
    @Published var defaultLabelSize: LabelSize = .narrow
    @Published var defaultItemSize: ItemSize = .square

    func addItem(label: String, imageData: Data? = nil) {
        let item = TierItem(
            label: label,
            imageData: imageData,
            itemSize: defaultItemSize  // デフォルトサイズを適用
        )
        pool.append(item)
        itemAddedCount += 1
    }

    func addRow() {
        let newRow = TierRow(
            tierName: "New",
            color: "#AAAAAA",
            labelSize: defaultLabelSize  // デフォルトサイズを適用
        )
        rows.append(newRow)
    }

    // ラベルサイズを全行に一括適用
    func applyLabelSizeToAll(_ size: LabelSize) {
        defaultLabelSize = size
        for i in rows.indices {
            rows[i].labelSize = size
        }
    }

    // アイテムサイズを全アイテムに一括適用
    func applyItemSizeToAll(_ size: ItemSize) {
        defaultItemSize = size
        // プール内のアイテム
        for i in pool.indices {
            pool[i].itemSize = size
        }
        // 各行のアイテム
        for i in rows.indices {
            for j in rows[i].items.indices {
                rows[i].items[j].itemSize = size
            }
        }
    }

    func moveItem(_ item: TierItem, toRowId rowId: UUID) {
        pool.removeAll { $0.id == item.id }
        for i in rows.indices {
            rows[i].items.removeAll { $0.id == item.id }
        }
        if let idx = rows.firstIndex(where: { $0.id == rowId }) {
            rows[idx].items.append(item)
        }
    }

    func returnToPool(_ item: TierItem) {
        for i in rows.indices {
            rows[i].items.removeAll { $0.id == item.id }
        }
        if !pool.contains(item) {
            pool.append(item)
        }
    }

    func removeRow(id: UUID) {
        if let idx = rows.firstIndex(where: { $0.id == id }) {
            let removedItems = rows[idx].items
            pool.append(contentsOf: removedItems)
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
}
