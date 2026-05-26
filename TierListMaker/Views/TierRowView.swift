import SwiftUI
internal import UniformTypeIdentifiers

struct TierRowView: View {

    let rowId: UUID
    @Binding var row: TierRow
    @ObservedObject var vm: TierListViewModel

    let dragPos: DragPositionState
    @ObservedObject var dragSel: DragInteractionState

    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    @Environment(\.tierTheme) private var tierTheme

    private var isHovered: Bool { dragSel.hoveredRowId == row.id }

    private var effectiveLabelSize: LabelSize { vm.defaultLabelSize }
    private var effectiveTextSize: LabelTextSize { vm.defaultLabelTextSize }
    private var effectiveItemSize: ItemSize { vm.defaultItemSize }

    // MARK: - Color キャッシュ
    private var labelColor: Color { Color(hex: row.color) }
    private var textColor:  Color { Color(hex: row.textColorHex) }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                tierLabel
                itemsArea
            }

            if dragSel.selectedItem != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let item = dragSel.selectedItem {
                            withAnimation(.spring()) {
                                vm.moveItem(item, toRowId: row.id)
                                dragSel.selectedItem = nil
                            }
                        }
                    }
            }
        }
        .clipped()
        .border(
            isHovered
                ? Color.blue
                : (dragSel.selectedItem != nil ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3)),
            width: isHovered ? 2 : (dragSel.selectedItem != nil ? 1.5 : 0.5)
        )
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
    //
    // GeometryReader をレイアウトコンテナとして使うと、
    // 視覚的な描画位置と SwiftUI のヒットテスト領域がずれる問題が発生する。
    //
    // 修正：.adaptive グリッドに切り替えることで LazyVGrid が
    // 自分のサイズを正確に自己報告するようにし、GeometryReader を排除。
    // min == max == itemWidth なので列幅は .fixed と同じく固定値になる。

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
                    dragSel: dragSel,
                    trayFrame: trayFrame
                )
                .opacity(dragSel.selectedItem?.id == item.id ? 0.3 : 1.0)
                .frame(
                    width: effectiveItemSize.width,
                    height: effectiveItemSize.height
                )
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background {
            ZStack {
                isHovered ? Color.blue.opacity(0.15) : tierTheme.rowBackground
                if !isHovered {
                    TierPatternView(
                        pattern: tierTheme.rowPattern,
                        color: tierTheme.patternColor
                    )
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
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
