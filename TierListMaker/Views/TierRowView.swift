import SwiftUI
internal import UniformTypeIdentifiers

struct TierRowView: View {

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
    @State private var showDeleteAlert = false

    private var isHovered: Bool {
        hoveredRowId == row.id
    }

    // ─────────────────────
    // 解決済み設定値
    // ─────────────────────

    private var effectiveLabelSize: LabelSize {
        row.labelSizeOverride ?? vm.defaultLabelSize
    }
    private var effectiveTextSize: LabelTextSize {
        row.labelTextSizeOverride ?? vm.defaultLabelTextSize
    }
    private var effectiveItemSize: ItemSize {
        row.rowItemSizeOverride ?? vm.defaultItemSize
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                // ティアラベル
                tierLabel
                // アイテムエリア
                GeometryReader { areaGeo in
                    let availableWidth =
                        areaGeo.size.width - 8
                    let itemW =
                        effectiveItemSize.width + 4
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
                    let itemH =
                        effectiveItemSize.height + 4
                    let calculatedHeight = max(
                        70,
                        CGFloat(rowCount) * itemH + 8
                    )
                    let columns = Array(
                        repeating: GridItem(
                            .fixed(effectiveItemSize.width),
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
                            .frame(
                                width: effectiveItemSize.width,
                                height: effectiveItemSize.height
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

            // 行全体タップ配置
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

        // 編集シート
        .sheet(isPresented: $showEditSheet) {
            TierRowEditSheet(
                row: $row,
                vm: vm
            )
        }

        // 削除確認
        .alert(
            "この行を削除しますか？",
            isPresented: $showDeleteAlert
        ) {
            Button(
                "削除",
                role: .destructive
            ) {
                withAnimation(.spring()) {
                    vm.removeRow(id: rowId)
                }
            }
            Button(
                "キャンセル",
                role: .cancel
            ) {}
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    // ラベルView
    private var tierLabel: some View {
        Text(row.tierName)
            .font(
                .system(
                    size: effectiveTextSize.fontSize,
                    weight: .bold
                )
            )
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: effectiveLabelSize.width)
            .frame(maxHeight: .infinity)
            .background(Color(hex: row.color))
            .foregroundColor(Color(hex: row.textColorHex))
            .onTapGesture(count: 2) {
                showEditSheet = true
            }
            .contextMenu {
                Button {
                    showEditSheet = true
                } label: {
                    Label(
                        "編集",
                        systemImage: "pencil"
                    )
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label(
                        "削除",
                        systemImage: "trash"
                    )
                }
            } preview: {
                previewContent
            }
    }

    // ContextMenu Preview
    private var previewContent: some View {
        HStack(spacing: 0) {
            Text(row.tierName)
                .font(
                    .system(
                        size: effectiveTextSize.fontSize,
                        weight: .bold
                    )
                )
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: effectiveLabelSize.width)
                .frame(maxHeight: .infinity)
                .background(Color(hex: row.color))
                .foregroundColor(Color(hex: row.textColorHex))
            LazyHStack(spacing: 4) {
                ForEach(row.items) { item in
                    TierItemView(item: item)
                }
            }
            .padding(4)
            .frame(
                maxWidth: .infinity,
                minHeight: 70
            )
            .background(Color(.systemGray6))
        }
        .frame(
            width: UIScreen.main.bounds.width,
            height: 70
        )
    }

    // 高さ計算
    private var itemAreaHeight: CGFloat {
        guard !row.items.isEmpty else {
            return 70
        }
        let labelW =
            effectiveLabelSize.width
        let totalW =
            UIScreen.main.bounds.width
            - labelW
            - 8
        let itemW =
            effectiveItemSize.width + 4
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
        let itemH =
            effectiveItemSize.height + 4
        return max(
            70,
            CGFloat(rowCount) * itemH + 8
        )
    }
}
