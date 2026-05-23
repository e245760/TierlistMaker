import Foundation

struct TierListSaveData: Identifiable, Codable {
    let id: UUID
    var title: String
    var rows: [TierRow]
    var pool: [TierItem]
    var defaultLabelSize: LabelSize
    var defaultLabelTextSize: LabelTextSize
    var defaultItemSize: ItemSize
    var theme: AppTheme          // ← 追加
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        rows: [TierRow],
        pool: [TierItem],
        defaultLabelSize: LabelSize,
        defaultLabelTextSize: LabelTextSize,
        defaultItemSize: ItemSize,
        theme: AppTheme = .light, // ← 追加
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.rows = rows
        self.pool = pool
        self.defaultLabelSize = defaultLabelSize
        self.defaultLabelTextSize = defaultLabelTextSize
        self.defaultItemSize = defaultItemSize
        self.theme = theme
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // 旧保存データとの後方互換（theme がない場合は .light をデフォルト）
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decode(UUID.self,          forKey: .id)
        title              = try c.decode(String.self,        forKey: .title)
        rows               = try c.decode([TierRow].self,     forKey: .rows)
        pool               = try c.decode([TierItem].self,    forKey: .pool)
        defaultLabelSize   = try c.decode(LabelSize.self,     forKey: .defaultLabelSize)
        defaultLabelTextSize = try c.decode(LabelTextSize.self, forKey: .defaultLabelTextSize)
        defaultItemSize    = try c.decode(ItemSize.self,      forKey: .defaultItemSize)
        theme              = try c.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .light
        createdAt          = try c.decode(Date.self,          forKey: .createdAt)
        updatedAt          = try c.decode(Date.self,          forKey: .updatedAt)
    }

    var totalItemCount: Int {
        rows.reduce(0) { $0 + $1.items.count } + pool.count
    }
}
