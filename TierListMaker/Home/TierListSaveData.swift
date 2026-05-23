import Foundation

struct TierListSaveData: Identifiable, Codable {
    let id: UUID
    var title: String
    var rows: [TierRow]
    var pool: [TierItem]
    var defaultLabelSize: LabelSize
    var defaultLabelTextSize: LabelTextSize
    var defaultItemSize: ItemSize
    var defaultItemTextSize: ItemTextSize
    var tierTheme: TierTheme
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
        defaultItemTextSize: ItemTextSize = .large,
        tierTheme: TierTheme = .classic,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id                  = id
        self.title               = title
        self.rows                = rows
        self.pool                = pool
        self.defaultLabelSize    = defaultLabelSize
        self.defaultLabelTextSize = defaultLabelTextSize
        self.defaultItemSize     = defaultItemSize
        self.defaultItemTextSize = defaultItemTextSize
        self.tierTheme           = tierTheme
        self.createdAt           = createdAt
        self.updatedAt           = updatedAt
    }

    // MARK: - Codable（後方互換）
    //
    // 旧フォーマット: "theme": "light" | "dark"  （AppTheme）
    // 新フォーマット: "tierTheme": "classic" | "dark" | ...  （TierTheme）
    //
    // デコード優先順位:
    //   1. "tierTheme" キーが存在すればそのまま使う
    //   2. なければ旧 "theme" キーを読み、"dark" → .dark、それ以外 → .classic にマッピング

    enum CodingKeys: String, CodingKey {
        case id, title, rows, pool
        case defaultLabelSize, defaultLabelTextSize
        case defaultItemSize, defaultItemTextSize
        case tierTheme
        case legacyTheme = "theme"   // 旧キー（読み取り専用）
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,          forKey: .id)
        title                = try c.decode(String.self,        forKey: .title)
        rows                 = try c.decode([TierRow].self,     forKey: .rows)
        pool                 = try c.decode([TierItem].self,    forKey: .pool)
        defaultLabelSize     = try c.decode(LabelSize.self,     forKey: .defaultLabelSize)
        defaultLabelTextSize = try c.decode(LabelTextSize.self, forKey: .defaultLabelTextSize)
        defaultItemSize      = try c.decode(ItemSize.self,      forKey: .defaultItemSize)
        defaultItemTextSize  = try c.decodeIfPresent(ItemTextSize.self, forKey: .defaultItemTextSize) ?? .large
        createdAt            = try c.decode(Date.self,          forKey: .createdAt)
        updatedAt            = try c.decode(Date.self,          forKey: .updatedAt)

        // tierTheme: 新キー優先 → 旧キーからマッピング → デフォルト
        if let t = try c.decodeIfPresent(TierTheme.self, forKey: .tierTheme) {
            tierTheme = t
        } else if let legacy = try c.decodeIfPresent(String.self, forKey: .legacyTheme) {
            tierTheme = legacy == "dark" ? .dark : .classic
        } else {
            tierTheme = .classic
        }
    }

    // encode は自動合成だと legacyTheme も出力されてしまうため明示する
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                   forKey: .id)
        try c.encode(title,                forKey: .title)
        try c.encode(rows,                 forKey: .rows)
        try c.encode(pool,                 forKey: .pool)
        try c.encode(defaultLabelSize,     forKey: .defaultLabelSize)
        try c.encode(defaultLabelTextSize, forKey: .defaultLabelTextSize)
        try c.encode(defaultItemSize,      forKey: .defaultItemSize)
        try c.encode(defaultItemTextSize,  forKey: .defaultItemTextSize)
        try c.encode(tierTheme,            forKey: .tierTheme)
        try c.encode(createdAt,            forKey: .createdAt)
        try c.encode(updatedAt,            forKey: .updatedAt)
        // legacyTheme は書き出さない
    }

    var totalItemCount: Int {
        rows.reduce(0) { $0 + $1.items.count } + pool.count
    }
}
