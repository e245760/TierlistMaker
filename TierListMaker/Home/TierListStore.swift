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
// ── 非同期ロード ──
//   init() でディレクトリ作成のみ行い、ファイル I/O は Task { await loadAsync() }
//   に委譲する。メインスレッドをブロックせず、起動時のヒッチを防ぐ。
//
// ── 書き込みの原子性 ──
//   upsert/delete ともにデータファイルと index.json を1つの Task にまとめて書く。
//   2つの Task に分けると、クラッシュ時に index が古いまま残るリスクがあった。
//
// ── マイグレーション ──
//   旧形式（UserDefaults "tierListStore_v1"）が存在する場合、
//   初回起動時に自動的に新形式へ変換する。
//   変換後、次回起動時に新形式で読み込めたことを確認してから旧データを削除する。

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
    //
    // ディレクトリ作成だけ同期で行い、ファイル I/O は非同期タスクに委譲する。
    // PurchaseManager.init() と同じパターン。

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("TierLists", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        directory = dir
        indexURL  = dir.appendingPathComponent("index.json")
        Task { await loadAsync() }
    }

    // MARK: - Public API

    func upsert(_ data: TierListSaveData) {
        if let idx = savedLists.firstIndex(where: { $0.id == data.id }) {
            savedLists[idx] = data
        } else {
            savedLists.insert(data, at: 0)
        }
        // データファイルと index.json を1つの Task にまとめて書く。
        // 分けると2つの Task の間にクラッシュした場合に index が不整合になるリスクがある。
        persistDataAndIndex(data)
    }

    func delete(id: UUID) {
        if let saveData = savedLists.first(where: { $0.id == id }) {
            deleteImageFiles(for: saveData)
        }
        savedLists.removeAll { $0.id == id }
        removeFileAndUpdateIndex(id: id)
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

    // MARK: - 永続化
    //
    // URL・Data・[String] はすべて値型（Sendable）なので Task.detached へ安全に渡せる。

    /// データファイル書き込み → index.json 書き込みを1つの Task で順番に実行する。
    /// 途中でクラッシュしても「index にないファイルが存在する」状態で済み、
    /// 「index にある UUID のファイルがない」状態（読み込みエラー）を避けられる。
    private func persistDataAndIndex(_ data: TierListSaveData) {
        let dataURL  = fileURL(for: data.id)
        let idxURL   = indexURL
        let ids      = savedLists.map { $0.id.uuidString }
        Task.detached(priority: .utility) {
            if let encoded = try? JSONEncoder().encode(data) {
                try? encoded.write(to: dataURL, options: .atomic)
            }
            if let encoded = try? JSONEncoder().encode(ids) {
                try? encoded.write(to: idxURL, options: .atomic)
            }
        }
    }

    /// ファイル削除 → index.json 更新を1つの Task で順番に実行する。
    private func removeFileAndUpdateIndex(id: UUID) {
        let dataURL = fileURL(for: id)
        let idxURL  = indexURL
        let ids     = savedLists.map { $0.id.uuidString }
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: dataURL)
            if let encoded = try? JSONEncoder().encode(ids) {
                try? encoded.write(to: idxURL, options: .atomic)
            }
        }
    }

    // MARK: - 読み込み（非同期）

    private func loadAsync() async {
        // バックグラウンドでファイル I/O を実行
        let result = await Task.detached(priority: .userInitiated) { [self] in
            loadFromFiles()
        }.value

        if let lists = result {
            // 新形式で読み込み成功
            savedLists = lists
            // 旧 UserDefaults が残っていれば削除（マイグレーション後の初回起動）
            if UserDefaults.standard.data(forKey: legacyKey) != nil {
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
        } else {
            // フォールバック: 旧形式からマイグレーション
            migrateLegacyIfNeeded()
        }
    }

    /// index.json を読み、UUID 順に個別ファイルをデコードして返す。
    /// index.json が存在しない場合は nil を返す（旧形式と区別するため）。
    /// Task.detached から呼ばれるため nonisolated で宣言する。
    private nonisolated func loadFromFiles() -> [TierListSaveData]? {
        let idxURL = indexURL
        guard
            let indexData = try? Data(contentsOf: idxURL),
            let ids       = try? JSONDecoder().decode([String].self, from: indexData)
        else { return nil }

        let decoder = JSONDecoder()
        var lists: [TierListSaveData] = []
        for uuidString in ids {
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            let url = directory.appendingPathComponent("\(uuid.uuidString).json")
            guard
                let fileData = try? Data(contentsOf: url),
                let decoded  = try? decoder.decode(TierListSaveData.self, from: fileData)
            else {
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
    // 次回起動時に loadAsync() が成功すれば削除される。

    private func migrateLegacyIfNeeded() {
        guard
            let data    = UserDefaults.standard.data(forKey: legacyKey),
            let decoded = try? JSONDecoder().decode([TierListSaveData].self, from: data)
        else { return }

        print("[TierListStore] 旧形式からマイグレーションを開始します（\(decoded.count)件）")
        savedLists = decoded
        for item in decoded { persistDataAndIndex(item) }
    }
}
