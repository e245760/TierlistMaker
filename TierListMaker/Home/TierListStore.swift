import SwiftUI
import Combine

class TierListStore: ObservableObject {
    @Published var savedLists: [TierListSaveData] = []

    private let storeKey = "tierListStore_v1"

    // MARK: - シリアルキュー
    //
    // .userInitiated: ユーザー操作に起因する保存なので高めの優先度
    // serial（デフォルト）なので複数の persist() が連続しても順番通りに実行される
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
        // 削除前に画像ファイル名を収集してからリストを削除する
        if let saveData = savedLists.first(where: { $0.id == id }) {
            deleteImageFiles(for: saveData)
        }
        savedLists.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 画像ファイル削除
    //
    // ティア表が持つ全アイテム（rows + pool）の imageFileName を収集し、
    // ImageFileStore に一括削除を依頼する。

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

    private func persist() {
        // メインスレッドで配列のスナップショットを取る
        // → キューが実行されるタイミングに関わらず、この時点の内容が書き込まれる
        let snapshot = savedLists

        saveQueue.async {
            guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(encoded, forKey: self.storeKey)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let decoded = try? JSONDecoder().decode([TierListSaveData].self, from: data)
        else { return }
        savedLists = decoded
    }
}
