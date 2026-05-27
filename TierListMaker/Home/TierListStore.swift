import SwiftUI
import Combine

// MARK: - TierListStore
//
// ── 保存形式 ──
//   Documents/TierLists/
//     index.json          … UUID 文字列の配列（表示順を管理）
//     {UUID}.json         … TierListSaveData を1件ずつ JSON 化
//
// upsert: 変更された1件のみ上書き → O(1) の書き込みコスト
// delete: 対象ファイルを削除 → 他の表に影響なし
// 全件を毎回エンコードする旧 UserDefaults 方式と異なり、
// 表の数が増えても書き込みコストが増加しない。
//
// ── マイグレーション ──
//   旧形式（UserDefaults "tierListStore_v1"）が存在する場合、
//   初回起動時に自動的に新形式へ変換する。
//   変換後、次回起動時に新形式で読み込めたことを確認してから旧データを削除する。
//   ファイル書き込みは非同期のため、同一起動内での削除は行わない。

@MainActor
class TierListStore: ObservableObject {
    @Published var savedLists: [TierListSaveData] = []

    // MARK: - ファイルパス

    private let directory: URL
    private let indexURL:  URL

    /// 旧 UserDefaults キー（マイグレーション用）
    private let legacyKey = "tierListStore_v1"

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - Init

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("TierLists", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        directory = dir
        indexURL  = dir.appendingPathComponent("index.json")
        load()
    }

    // MARK: - Public API

    func upsert(_ data: TierListSaveData) {
        if let idx = savedLists.firstIndex(where: { $0.id == data.id }) {
            savedLists[idx] = data
        } else {
            savedLists.insert(data, at: 0)
        }
        // 変更された1件だけを書き込む（全件書き込みは不要）
        persistSingle(data)
        persistIndex()
    }

    func delete(id: UUID) {
        if let saveData = savedLists.first(where: { $0.id == id }) {
            deleteImageFiles(for: saveData)
        }
        savedLists.removeAll { $0.id == id }
        removeFile(id: id)
        persistIndex()
    }

    // MARK: - 画像ファイル削除

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

    // MARK: - 永続化（個別ファイル）
    //
    // URL をメインスレッドで計算してからタスクに渡す。
    // URL・Data はどちらも値型（Sendable）なので Task.detached へ安全に渡せる。

    private func persistSingle(_ data: TierListSaveData) {
        let url = fileURL(for: data.id)
        Task.detached(priority: .utility) {
            guard let encoded = try? JSONEncoder().encode(data) else { return }
            try? encoded.write(to: url, options: .atomic)
        }
    }

    /// index.json に UUID 文字列の配列を書き込む（表示順の管理）
    private func persistIndex() {
        let ids = savedLists.map { $0.id.uuidString }
        let url = indexURL
        Task.detached(priority: .utility) {
            guard let encoded = try? JSONEncoder().encode(ids) else { return }
            try? encoded.write(to: url, options: .atomic)
        }
    }

    private func removeFile(id: UUID) {
        let url = fileURL(for: id)
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 読み込み

    private func load() {
        // 優先: 新形式（index.json + 個別ファイル）
        if let lists = loadFromFiles() {
            savedLists = lists
            // 新形式で正常に読み込めた → 旧 UserDefaults が残っていれば削除
            // （マイグレーション後の初回起動でここに到達する）
            if UserDefaults.standard.data(forKey: legacyKey) != nil {
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
            return
        }
        // フォールバック: 旧形式からマイグレーション
        migrateLegacyIfNeeded()
    }

    /// index.json を読み、UUID 順に個別ファイルをデコードして返す。
    /// index.json が存在しない場合は nil を返す（旧形式と区別するため）。
    private func loadFromFiles() -> [TierListSaveData]? {
        guard
            let indexData = try? Data(contentsOf: indexURL),
            let ids       = try? JSONDecoder().decode([String].self, from: indexData)
        else { return nil }

        let decoder = JSONDecoder()
        var lists: [TierListSaveData] = []
        for uuidString in ids {
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            let url = fileURL(for: uuid)
            guard
                let fileData = try? Data(contentsOf: url),
                let decoded  = try? decoder.decode(TierListSaveData.self, from: fileData)
            else {
                // ファイルが欠損している場合はスキップ（他の表には影響しない）
                print("[TierListStore] ファイルが見つかりません: \(uuidString).json")
                continue
            }
            lists.append(decoded)
        }
        return lists
    }

    // MARK: - マイグレーション
    //
    // 旧形式: UserDefaults に [TierListSaveData] を全件 JSON エンコード
    // 新形式: Documents/TierLists/{UUID}.json + index.json
    //
    // ファイル書き込みは非同期のため、UserDefaults の削除はここでは行わない。
    // 次回起動時に loadFromFiles() が成功すれば load() 内で削除される。

    private func migrateLegacyIfNeeded() {
        guard
            let data    = UserDefaults.standard.data(forKey: legacyKey),
            let decoded = try? JSONDecoder().decode([TierListSaveData].self, from: data)
        else { return }

        print("[TierListStore] 旧形式からマイグレーションを開始します（\(decoded.count)件）")
        savedLists = decoded
        for item in decoded { persistSingle(item) }
        persistIndex()
        // UserDefaults は次回起動（新形式で読み込み成功後）に削除する
    }
}
