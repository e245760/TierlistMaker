import SwiftUI

// MARK: - SortOrder

enum LibrarySortOrder: String, CaseIterable {
    case updatedDesc = "updatedDesc"   // 更新日時（新しい順）← デフォルト
    case updatedAsc  = "updatedAsc"    // 更新日時（古い順）
    case titleAsc    = "titleAsc"      // タイトル（あいうえお順）
    case createdDesc = "createdDesc"   // 作成日時（新しい順）

    var label: String {
        switch self {
        case .updatedDesc: return "更新日時（新しい順）"
        case .updatedAsc:  return "更新日時（古い順）"
        case .titleAsc:    return "タイトル順"
        case .createdDesc: return "作成日時（新しい順）"
        }
    }

    var icon: String {
        switch self {
        case .updatedDesc: return "arrow.down.circle"
        case .updatedAsc:  return "arrow.up.circle"
        case .titleAsc:    return "textformat.abc"
        case .createdDesc: return "calendar.badge.clock"
        }
    }

    func sorted(_ lists: [TierListSaveData]) -> [TierListSaveData] {
        switch self {
        case .updatedDesc: return lists.sorted { $0.updatedAt > $1.updatedAt }
        case .updatedAsc:  return lists.sorted { $0.updatedAt < $1.updatedAt }
        case .titleAsc:    return lists.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .createdDesc: return lists.sorted { $0.createdAt > $1.createdAt }
        }
    }
}

struct LibraryView: View {
    @ObservedObject var store: TierListStore
    @EnvironmentObject private var pm: PurchaseManager
    let onOpen: (TierListSaveData?) -> Void

    @State private var deletingId: UUID? = nil
    @State private var showDeleteAlert = false
    @State private var renamingId: UUID? = nil
    @State private var renameText: String = ""
    @State private var showRenameAlert = false
    @State private var showSortDialog = false
    @AppStorage("librarySortOrder") private var sortOrder: LibrarySortOrder = .updatedDesc

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    // 上限に達しているか
    private var isAtLimit: Bool {
        !pm.canCreate(currentCount: store.savedLists.count)
    }

    // ソート済みリスト
    private var sortedLists: [TierListSaveData] {
        sortOrder.sorted(store.savedLists)
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.savedLists.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        // ── 使用状況バー ──
                        limitBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(sortedLists) { saveData in
                                LibraryCardCell(
                                    saveData: saveData,
                                    onOpen: { onOpen(saveData) },
                                    onRename: {
                                        renamingId      = saveData.id
                                        renameText      = saveData.title
                                        showRenameAlert = true
                                    },
                                    onDuplicate: { store.duplicate(id: saveData.id) },
                                    onDelete: {
                                        deletingId      = saveData.id
                                        showDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("ライブラリ")
            .toolbar {
                // ── ソートボタン ──
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSortDialog = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.body)
                    }
                }

                // ── 新規作成ボタン ──
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onOpen(nil)
                    } label: {
                        Image(systemName: isAtLimit ? "lock.fill" : "plus")
                            .font(.body.bold())
                            .foregroundColor(isAtLimit ? .orange : .blue)
                    }
                }
            }
            .alert("削除しますか？", isPresented: $showDeleteAlert) {
                Button("削除", role: .destructive) {
                    if let id = deletingId { store.delete(id: id) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
            .confirmationDialog("並び替え", isPresented: $showSortDialog, titleVisibility: .visible) {
                ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                    Button {
                        withAnimation(.spring()) { sortOrder = order }
                    } label: {
                        Text(order.label + (sortOrder == order ? " ✓" : ""))
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .alert("名前を変更", isPresented: $showRenameAlert) {
                TextField("ティア表の名前", text: $renameText)
                    .autocorrectionDisabled(true)
                Button("変更") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    if let id = renamingId, !trimmed.isEmpty {
                        store.rename(id: id, title: trimmed)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    // MARK: - 使用状況バー

    @ViewBuilder
    private var limitBanner: some View {
        let count = store.savedLists.count
        let limit = pm.limit
        let progress = Double(count) / Double(limit)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(count) / \(limit)個使用中")
                    .font(.caption.bold())
                    .foregroundColor(isAtLimit ? .orange : .secondary)

                Spacer()

                if isAtLimit {
                    // 上限到達時：アップグレード誘導テキスト
                    Button {
                        onOpen(nil)   // → HomeView でペイウォールが開く
                    } label: {
                        Label("アップグレード", systemImage: "star.fill")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                } else if pm.isPro {
                    Label("プロ", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }

            // プログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 5)
                    Capsule()
                        .fill(isAtLimit ? Color.orange : Color.blue)
                        .frame(width: geo.size.width * progress, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("ティア表がありません")
                .font(.title3.bold())
            Text("「＋」ボタンから\n新しいティア表を作成しましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onOpen(nil)
            } label: {
                Label("新規作成", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - LibraryCardCell
//
// TierListCard とメニューを1つのビューにまとめた セル。
// ForEach のクロージャから切り出すことで、メニュー操作時の
// LazyVGrid 全体の再評価を防ぐ。
// saveData が変わらない限り TierListCard の再描画をスキップする。

private struct LibraryCardCell: View {
    let saveData: TierListSaveData
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var showActions = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TierListCard(saveData: saveData)
                .equatable()
                .onTapGesture { onOpen() }

            Button {
                showActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .confirmationDialog(saveData.title, isPresented: $showActions, titleVisibility: .visible) {
            Button("名前を変更") { onRename() }
            Button("複製") { onDuplicate() }
            Button("削除", role: .destructive) { onDelete() }
            Button("キャンセル", role: .cancel) {}
        }
    }
}

// MARK: - Tier List Card

struct TierListCard: View, Equatable {
    let saveData: TierListSaveData

    // Equatable: saveDataが同一であればbodyの再評価をスキップする
    static func == (lhs: TierListCard, rhs: TierListCard) -> Bool {
        lhs.saveData == rhs.saveData
    }

    private struct RowColors {
        let label: Color
        let items: [Color]
    }
    private var previewRowColors: [RowColors] {
        saveData.rows.prefix(6).map { row in
            RowColors(
                label: Color(hex: row.color),
                items: row.items.prefix(8).map { Color(hex: $0.backgroundColorHex) }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tierPreview
                .frame(height: 110)

            VStack(alignment: .leading, spacing: 4) {
                Text(saveData.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundColor(.primary)

                HStack(spacing: 6) {
                    Label("\(saveData.rows.count)行", systemImage: "list.dash")
                    Text("·")
                    Label("\(saveData.totalItemCount)個", systemImage: "square.grid.2x2")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(relativeDate)
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
    }

    private var tierPreview: some View {
        let rowColors = previewRowColors
        return GeometryReader { geo in
            let count = max(1, rowColors.count)
            let gap: CGFloat = 1
            let rowH = (geo.size.height - gap * CGFloat(count - 1)) / CGFloat(count)

            VStack(spacing: gap) {
                ForEach(Array(rowColors.enumerated()), id: \.offset) { index, rc in
                    HStack(spacing: gap) {
                        rc.label
                            .frame(width: 22)
                        if rc.items.isEmpty {
                            Color(.systemGray5)
                        } else {
                            HStack(spacing: 2) {
                                ForEach(Array(rc.items.enumerated()), id: \.offset) { _, color in
                                    color.clipShape(RoundedRectangle(cornerRadius: 2))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 2)
                            .background(Color(.systemGray5))
                        }
                    }
                    .frame(height: max(1, rowH))
                }
            }
        }
        .background(Color(.systemGray5))
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: saveData.updatedAt, relativeTo: Date())
    }
}
