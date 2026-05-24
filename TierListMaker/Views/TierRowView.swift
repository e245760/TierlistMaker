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
    // body 内で同じ Color(hex:) を何度も呼ぶ代わりに1回だけ生成して使い回す。
    // row が変化すると body が再描画されるため、値は常に最新になる。
    private var labelColor: Color { Color(hex: row.color) }
    private var textColor:  Color { Color(hex: row.textColorHex) }

    // MARK: - 高さ状態
    // GeometryReader の正確な幅から計算した高さを保持する。
    // これにより UIScreen.main.bounds.width を使う itemAreaHeight が不要になり、
    // 重複計算が解消される。
    @State private var computedHeight: CGFloat = 70

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                tierLabel

                GeometryReader { areaGeo in
                    let availableWidth = areaGeo.size.width - 8
                    let itemW = effectiveItemSize.width + 4
                    let cols = max(1, Int(availableWidth / itemW))
                    let rowCount = max(
                        1,
                        Int(ceil(Double(row.items.count) / Double(cols)))
                    )
                    let itemH = effectiveItemSize.height + 4
                    let calculatedHeight = max(70, CGFloat(rowCount) * itemH + 8)
                    let columns = Array(
                        repeating: GridItem(.fixed(effectiveItemSize.width), spacing: 4),
                        count: cols
                    )

                    LazyVGrid(columns: columns, spacing: 4) {
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
                    .frame(
                        width: areaGeo.size.width,
                        height: calculatedHeight,
                        alignment: .leading
                    )
                    // GeometryReader が確定した高さを @State に書き戻す。
                    // 外側の .frame(minHeight:) がこれを使うため、
                    // UIScreen.main.bounds.width による近似計算が不要になる。
                    .onChange(of: calculatedHeight) { computedHeight = $0 }
                    .onAppear { computedHeight = calculatedHeight }
                }
                .frame(minHeight: computedHeight)
                .background(
                    isHovered ? Color.blue.opacity(0.15) : tierTheme.rowBackground
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .onDrop(of: [.text], isTargeted: nil) { _ in false }
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

    // MARK: - ラベルView

    private var tierLabel: some View {
        Text(row.tierName)
            .font(.system(size: effectiveTextSize.fontSize, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: effectiveLabelSize.width)
            .frame(maxHeight: .infinity)
            .background(labelColor)   // ← キャッシュ済み
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
                .font(.system(size: effectiveTextSize.fontSize, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: effectiveLabelSize.width)
                .frame(maxHeight: .infinity)
                .background(labelColor)   // ← キャッシュ済み
                .foregroundColor(textColor)
            LazyHStack(spacing: 4) {
                ForEach(row.items) { item in
                    TierItemView(item: item)
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(tierTheme.rowBackground)
        }
        .frame(width: UIScreen.main.bounds.width, height: 70)
    }
}
