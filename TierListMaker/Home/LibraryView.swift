import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: TierListStore
    let onOpen: (TierListSaveData?) -> Void

    @State private var deletingId: UUID? = nil
    @State private var showDeleteAlert = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.savedLists.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.savedLists) { saveData in
                                TierListCard(saveData: saveData)
                                    .onTapGesture { onOpen(saveData) }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deletingId = saveData.id
                                            showDeleteAlert = true
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("ライブラリ")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onOpen(nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.bold())
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
        }
    }

    // ── 空状態 ──
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

// MARK: - Tier List Card

struct TierListCard: View {
    let saveData: TierListSaveData

    // MARK: - Color 事前計算
    //
    // GeometryReader + ForEach の中で Color(hex:) を呼ぶと、
    // スクロールや再描画のたびに全行・全アイテム分の変換が走る。
    // saveData（let）を元に body の外で一度だけ計算しておく。
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

    // ティア行の色帯（ラベル色 + アイテムエリア）
    private var tierPreview: some View {
        // previewRowColors を body の前に計算済みのため、
        // GeometryReader 内では Color(hex:) を呼ばずに済む。
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
