import SwiftUI
import Combine

class TierListStore: ObservableObject {
    @Published var savedLists: [TierListSaveData] = []

    private let storeKey = "tierListStore_v1"

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
        guard let encoded = try? JSONEncoder().encode(savedLists) else { return }
        UserDefaults.standard.set(encoded, forKey: storeKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let decoded = try? JSONDecoder().decode([TierListSaveData].self, from: data)
        else { return }
        savedLists = decoded
    }
}
