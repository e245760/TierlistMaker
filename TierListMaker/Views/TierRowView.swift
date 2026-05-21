import SwiftUI
internal import UniformTypeIdentifiers

struct TierRowView: View {

    // ← 固定IDを持たせる
    let rowId: UUID

    @Binding var row: TierRow
    @ObservedObject var vm: TierListViewModel
    @Binding var selectedItem: TierItem?
    @Binding var draggingItem: TierItem?
    @Binding var dragLocation: CGPoint
    @Binding var hoveredRowId: UUID?

    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var showEditSheet = false

    // 削除確認用
    @State private var showDeleteAlert = false

    private var isHovered: Bool {
        hoveredRowId == row.id
    }

    var body: some View {

        ZStack(alignment: .trailing) {

            HStack(spacing: 0) {

                // ─────────────────────
                // ティアラベル
                // ─────────────────────

                Text(row.tierName)
                    .font(.system(size: row.labelTextSize.fontSize, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: row.labelSize.width)
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: row.color))
                    .foregroundColor(.black)

                    // ダブルタップ編集
                    .onTapGesture(count: 2) {
                        showEditSheet = true
                    }

                    // Context Menu
                    .contextMenu {

                        Button {
                            showEditSheet = true
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }

                        Button(role: .destructive) {

                            // ← 即削除しない
                            showDeleteAlert = true

                        } label: {
                            Label("削除", systemImage: "trash")
                        }

                    } preview: {

                        HStack(spacing: 0) {

                            Text(row.tierName)
                                .font(.system(size: row.labelTextSize.fontSize, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: row.labelSize.width)
                                .frame(maxHeight: .infinity)
                                .background(Color(hex: row.color))
                                .foregroundColor(.black)

                            LazyHStack(spacing: 4) {

                                ForEach(row.items) { item in
                                    TierItemView(item: item)
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .background(Color(.systemGray6))
                        }
                        .frame(
                            width: UIScreen.main.bounds.width,
                            height: 70
                        )
                    }

                // ─────────────────────
                // アイテムエリア
                // ─────────────────────

                GeometryReader { areaGeo in

                    let availableWidth = areaGeo.size.width - 8

                    // 最大サイズ基準
                    let maxItemW =
                        row.items.map { $0.itemSize.width }.max()
                        ?? vm.defaultItemSize.width

                    let itemW = maxItemW + 4

                    let cols = max(
                        1,
                        Int(availableWidth / itemW)
                    )

                    let rowCount = max(
                        1,
                        Int(
                            ceil(
                                Double(row.items.count)
                                / Double(cols)
                            )
                        )
                    )

                    let maxItemH =
                        row.items.map { $0.itemSize.height }.max()
                        ?? vm.defaultItemSize.height

                    let itemH = maxItemH + 4

                    let calculatedHeight = max(
                        70,
                        CGFloat(rowCount) * itemH + 8
                    )

                    let columns = Array(
                        repeating: GridItem(
                            .fixed(maxItemW),
                            spacing: 4
                        ),
                        count: cols
                    )

                    LazyVGrid(
                        columns: columns,
                        spacing: 4
                    ) {

                        ForEach(row.items) { item in

                            DraggableTierItem(
                                item: item,
                                vm: vm,
                                rowFrames: rowFrames,
                                onTap: {

                                    withAnimation(.spring()) {
                                        selectedItem = item
                                    }
                                },
                                draggingItem: $draggingItem,
                                dragLocation: $dragLocation,
                                hoveredRowId: $hoveredRowId,
                                selectedItem: $selectedItem,
                                trayFrame: trayFrame
                            )
                            .opacity(
                                selectedItem?.id == item.id
                                ? 0.3
                                : 1.0
                            )

                            // サイズ統一
                            .frame(
                                width: maxItemW,
                                height: maxItemH
                            )
                        }
                    }
                    .padding(4)
                    .frame(
                        width: areaGeo.size.width,
                        height: calculatedHeight,
                        alignment: .leading
                    )
                }
                .frame(minHeight: itemAreaHeight)

                .background(
                    isHovered
                    ? Color.blue.opacity(0.15)
                    : Color(.systemGray6)
                )

                .animation(
                    .easeInOut(duration: 0.15),
                    value: isHovered
                )

                .onDrop(of: [.text], isTargeted: nil) { _ in
                    false
                }
            }

            // ─────────────────────
            // 行全体タップ配置
            // ─────────────────────

            if selectedItem != nil {

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {

                        if let item = selectedItem {

                            withAnimation(.spring()) {

                                vm.moveItem(
                                    item,
                                    toRowId: row.id
                                )

                                selectedItem = nil
                            }
                        }
                    }
            }
        }

        .clipped()

        .border(
            isHovered
            ? Color.blue
            : (
                selectedItem != nil
                ? Color.blue.opacity(0.5)
                : Color.gray.opacity(0.3)
            ),
            width:
                isHovered
                ? 2
                : (
                    selectedItem != nil
                    ? 1.5
                    : 0.5
                )
        )

        // ─────────────────────
        // 編集シート
        // ─────────────────────

        .sheet(isPresented: $showEditSheet) {

            TierRowEditSheet(row: $row)
        }

        // ─────────────────────
        // 削除確認
        // ─────────────────────

        .alert(
            "この行を削除しますか？",
            isPresented: $showDeleteAlert
        ) {

            Button("削除", role: .destructive) {

                // ← row.id を使わない
                // 固定IDを使う
                withAnimation(.spring()) {
                    vm.removeRow(id: rowId)
                }
            }

            Button("キャンセル", role: .cancel) {}

        } message: {

            Text("この操作は取り消せません。")
        }
    }

    // ─────────────────────
    // 高さ計算
    // ─────────────────────

    private var itemAreaHeight: CGFloat {

        guard !row.items.isEmpty else {
            return 70
        }

        let labelW = row.labelSize.width

        let totalW =
            UIScreen.main.bounds.width
            - labelW
            - 8

        let maxItemW =
            row.items.map { $0.itemSize.width }.max()
            ?? vm.defaultItemSize.width

        let itemW = maxItemW + 4

        let cols = max(
            1,
            Int(totalW / itemW)
        )

        let rowCount = max(
            1,
            Int(
                ceil(
                    Double(row.items.count)
                    / Double(cols)
                )
            )
        )

        let maxItemH =
            row.items.map { $0.itemSize.height }.max()
            ?? vm.defaultItemSize.height

        let itemH = maxItemH + 4

        return max(
            70,
            CGFloat(rowCount) * itemH + 8
        )
    }
}
