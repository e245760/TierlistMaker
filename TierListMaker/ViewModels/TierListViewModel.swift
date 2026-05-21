//
//  TierListViewModel.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/18.
//

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
    @Published var pool: [TierItem] = []  // 未分類アイテム

    // アイテムをプールに追加
    func addItem(label: String, imageData: Data? = nil) {
        let item = TierItem(label: label, imageData: imageData)
        pool.append(item)
    }

    // アイテムをティアに移動
    func moveItem(_ item: TierItem, toRowId rowId: UUID) {
        // プールから削除
        pool.removeAll { $0.id == item.id }
        // 他のティアからも削除
        for i in rows.indices {
            rows[i].items.removeAll { $0.id == item.id }
        }
        // 対象ティアに追加
        if let idx = rows.firstIndex(where: { $0.id == rowId }) {
            rows[idx].items.append(item)
        }
    }

    // アイテムをプールに戻す
    func returnToPool(_ item: TierItem) {
        for i in rows.indices {
            rows[i].items.removeAll { $0.id == item.id }
        }
        if !pool.contains(item) {
            pool.append(item)
        }
    }

    // ティアの追加・削除
    func addRow() {
        let newRow = TierRow(tierName: "New", color: "#AAAAAA")
        rows.append(newRow)
    }

    func removeRow(id: UUID) {
        if let idx = rows.firstIndex(where: { $0.id == id }) {
            let removedItems = rows[idx].items
            pool.append(contentsOf: removedItems)
            rows.remove(at: idx)
        }
    }
}
