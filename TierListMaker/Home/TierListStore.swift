import SwiftUI
import Combine

// 変更前
@MainActor  // ← 追加
class TierListStore: ObservableObject {
    @Published var savedLists: [TierListSaveData] = []

    private let storeKey = "tierListStore_v1"

    private let saveQueue = DispatchQueue(
        label: "com.app.tierlist.store",
        qos: .userInitiated
    )

    init() { load() }

    func upsert(_ data: TierListSaveData) {
        if let idx = savedLists.firstIndex(where: { $0.id == data.id }) {
            savedLists[idx] = data
        } else {
            savedLists.insert(data, at: 0)
        }
        persist()
    }

    func delete(id: UUID) {
        if let saveData = savedLists.first(where: { $0.id == id }) {
            deleteImageFiles(for: saveData)
        }
        savedLists.removeAll { $0.id == id }
        persist()
    }

    private func deleteImageFiles(for saveData: TierListSaveData) {
        var fileNames: [String] = []
        for row in saveData.rows {
            for item in row.items {
                if let name = item.imageFileName { fileNames.append(name) }
            }
        }
        for item in saveData.pool {
            if let name = item.imageFileName { fileNames.append(name) }
        }
        ImageFileStore.shared.delete(fileNames: fileNames)
    }

    // MARK: - 永続化
    //
    // @MainActor クラスなので savedLists へのアクセスは常にメインスレッド。
    // スナップショットを nonisolated な Task に渡してバックグラウンドで書き込む。
    // DispatchQueue は不要になるため削除。

    private func persist() {
        let snapshot = savedLists           // メインスレッドで安全にコピー
        Task.detached(priority: .utility) { // バックグラウンドで書き込み
            guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(encoded, forKey: "tierListStore_v1")
        }
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storeKey),
            let decoded = try? JSONDecoder().decode([TierListSaveData].self, from: data)
        else { return }
        savedLists = decoded
    }
}
