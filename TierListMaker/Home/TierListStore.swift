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
        savedLists.removeAll { $0.id == id }
        persist()
    }

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
