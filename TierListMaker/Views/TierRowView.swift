import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - RowHoverBackground
//
// アイテムエリアの背景をホバー状態に応じて切り替える。
// DragHoverState のみを購読するため、selectedItem / draggingItem の変化では再描画されない。
// hoveredRowId の変化時も、LazyVGrid を含まないこの軽量ビューだけが再描画される。

private struct RowHoverBackground: View {
    let rowId: UUID
    @ObservedObject var dragHover: DragHoverState
    let tierTheme: TierTheme

    private var isHovered: Bool { dragHover.hoveredRowId == rowId }

    var body: some View {
        Group {
            if isHovered {
                Color.blue.opacity(0.15)
            } else {
                ZStack {
                    tierTheme.rowBackground
                    TierPatternView(
                        pattern: tierTheme.rowPattern,
                        color: tierTheme.patternColor
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - RowBorder
//
// 行全体の境界線をホバー・選択状態に応じて切り替える。
// hoveredRowId（中頻度）と selectedItem（低頻度）の両方を参照するが、
// 境界線のみを描画する軽量ビューなので再描画コストは小さい。

private struct RowBorder: View {
    let rowId: UUID
    @ObservedObject var dragHover: DragHoverState
    @ObservedObject var dragSel: DragInteractionState

    private var isHovered: Bool { dragHover.hoveredRowId == rowId }

    var body: some View {
        let color: Color = isHovered
            ? .blue
            : (dragSel.selectedItem != nil ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3))
        let width: CGFloat = isHovered
            ? 2
            : (dragSel.selectedItem != nil ? 1.5 : 0.5)
        Rectangle().strokeBorder(color, lineWidth: width)
    }
}

// MARK: - RowTapOverlay
//
// 選択アイテム待機中に行全体をタップ可能にする透明オーバーレイ。
// DragInteractionState のみを購読する。selectedItem が nil のときはビューを生成しない。

private struct RowTapOverlay: View {
    let rowId: UUID
    @ObservedObject var dragSel: DragInteractionState
    let vm: TierListViewModel

    var body: some View {
        if dragSel.selectedItem != nil {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if let item = dragSel.selectedItem {
                        withAnimation(.spring()) {
                            vm.moveItem(item, toRowId: rowId)
                            dragSel.selectedItem = nil
                        }
                    }
                }
        }
    }
}

// MARK: - TierRowView

struct TierRowView: View {

    let rowId: UUID
    @Binding var row: TierRow
    @ObservedObject var vm: TierListViewModel

    let dragPos: DragPositionState
    // dragHover / dragSel は let（@ObservedObject ではない）。
    // 再描画は上記の子ビューが各自担うため、TierRowView 本体は
    // row / vm の変化時のみ再描画される。
    let dragHover: DragHoverState
    let dragSel: DragInteractionState

    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    @Environment(\.tierTheme) private var tierTheme

    private var effectiveLabelSize: LabelSize { vm.defaultLabelSize }
    private var effectiveTextSize: LabelTextSize { vm.defaultLabelTextSize }
    private var effectiveItemSize: ItemSize { vm.defaultItemSize }

    private var labelColor: Color { Color(hex: row.color) }
    private var textColor:  Color { Color(hex: row.textColorHex) }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                tierLabel
                itemsArea
            }
            // 選択アイテム待機中のタップ領域（子ビューで購読）
            RowTapOverlay(rowId: rowId, dragSel: dragSel, vm: vm)
        }
        .clipped()
        .overlay {
            // ホバー・選択状態に応じたボーダー（子ビューで購読）
            RowBorder(rowId: rowId, dragHover: dragHover, dragSel: dragSel)
        }
        .sheet(isPresented: $showEditSheet) {
            TierRowEditSheet(row: $row, vm: vm)
        }
        .alert("この行を削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                withAnimation(.spring()) { vm.removeRow(id: rowId) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
    }

    // MARK: - アイテムエリア

    private var itemsArea: some View {
        let columns = [
            GridItem(
                .adaptive(
                    minimum: effectiveItemSize.width,
                    maximum: effectiveItemSize.width
                ),
                spacing: 4
            )
        ]

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(row.items) { item in
                DraggableTierItem(
                    item: item,
                    vm: vm,
                    rowFrames: rowFrames,
                    onTap: {
                        withAnimation(.spring()) { dragSel.selectedItem = item }
                    },
                    dragPos: dragPos,
                    dragHover: dragHover,
                    dragSel: dragSel,
                    trayFrame: trayFrame
                )
                // opacity は DraggableTierItem 内の isSelectedItem / isDraggingThis で管理
                .frame(
                    width: effectiveItemSize.width,
                    height: effectiveItemSize.height
                )
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background {
            // 背景は RowHoverBackground が購読・描画（TierRowView 本体は非購読）
            RowHoverBackground(rowId: rowId, dragHover: dragHover, tierTheme: tierTheme)
        }
        .onDrop(of: [.text], isTargeted: nil) { _ in false }
    }

    // MARK: - ラベルView

    private var tierLabel: some View {
        Text(row.tierName)
            .font(tierTheme.fontStyle.font(size: effectiveTextSize.fontSize))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: effectiveLabelSize.width)
            .frame(maxHeight: .infinity)
            .background(labelColor)
            .foregroundColor(textColor)
            .onTapGesture(count: 2) { showEditSheet = true }
            .contextMenu {
                Button { showEditSheet = true } label: {
                    Label("編集", systemImage: "pencil")
                }
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("削除", systemImage: "trash")
                }
            } preview: {
                previewContent
            }
    }

    // MARK: - ContextMenu Preview

    private var previewContent: some View {
        HStack(spacing: 0) {
            Text(row.tierName)
                .font(tierTheme.fontStyle.font(size: effectiveTextSize.fontSize))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: effectiveLabelSize.width)
                .frame(maxHeight: .infinity)
                .background(labelColor)
                .foregroundColor(textColor)
            LazyHStack(spacing: 4) {
                ForEach(row.items) { item in
                    TierItemView(item: item)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background {
                ZStack {
                    tierTheme.rowBackground
                    TierPatternView(
                        pattern: tierTheme.rowPattern,
                        color: tierTheme.patternColor
                    )
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: 70)
    }
}
