import Foundation

struct TierListSaveData: Identifiable, Codable {
    let id: UUID
    var title: String
    var rows: [TierRow]
    var pool: [TierItem]
    var defaultLabelSize: LabelSize
    var defaultLabelTextSize: LabelTextSize
    var defaultItemSize: ItemSize
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var totalItemCount: Int {
        rows.reduce(0) { $0 + $1.items.count } + pool.count
    }
}
