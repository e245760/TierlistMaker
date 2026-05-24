import UIKit

// MARK: - ImageFileStore
//
// 画像ファイルを Documents/TierImages/ に保存・読み込み・削除する。
// NSCache によるメモリキャッシュを持つため、同じファイルへの連続アクセスはディスクを読まない。
//
// ── 使い方 ──
//   保存: ImageFileStore.shared.save(data, fileName: name)
//   読込: ImageFileStore.shared.load(fileName: name)   → UIImage?
//   削除: ImageFileStore.shared.delete(fileName: name)
//   命名: ImageFileStore.shared.fileName(for: itemId)  → "UUID.jpg"

final class ImageFileStore {

    static let shared = ImageFileStore()

    // MARK: - 保存先ディレクトリ

    private let directory: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = docs.appendingPathComponent("TierImages", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - メモリキャッシュ
    //
    // NSCache はメモリ逼迫時にエントリを自動解放するため、手動管理が不要。

    private let cache = NSCache<NSString, UIImage>()

    // MARK: - ファイル名生成

    /// アイテムIDから保存ファイル名を生成する（"{UUID}.jpg"）
    func fileName(for itemId: UUID) -> String {
        "\(itemId.uuidString).jpg"
    }

    // MARK: - 保存

    @discardableResult
    func save(_ data: Data, fileName: String) -> Bool {
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            // 保存成功時にキャッシュも更新
            if let image = UIImage(data: data) {
                cache.setObject(image, forKey: fileName as NSString)
            }
            return true
        } catch {
            print("[ImageFileStore] save failed: \(error)")
            return false
        }
    }

    // MARK: - 読み込み

    func load(fileName: String) -> UIImage? {
        // キャッシュヒット
        if let cached = cache.object(forKey: fileName as NSString) {
            return cached
        }
        // ディスクから読み込み
        let url = directory.appendingPathComponent(fileName)
        guard
            let data  = try? Data(contentsOf: url),
            let image = UIImage(data: data)
        else { return nil }
        // キャッシュに登録
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    // MARK: - 削除

    func delete(fileName: String) {
        cache.removeObject(forKey: fileName as NSString)
        let url = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func delete(fileNames: [String]) {
        fileNames.forEach { delete(fileName: $0) }
    }
}
