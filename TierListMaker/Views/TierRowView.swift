import SwiftUI
internal import UniformTypeIdentifiers

// MARK: - RowHoverBackground
//
// アイテムエリアの背景をホバー状態に応じて切り替える。
// DragHoverState のみを購読するため、selectedItem / draggingItem の変化では再描画されない。

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
// 行ドラッグ中は非表示にして競合を避ける。

private struct RowTapOverlay: View {
    let rowId: UUID
    @ObservedObject var dragSel: DragInteractionState
    @ObservedObject var rowDragState: RowDragState
    let vm: TierListViewModel

    private var isActive: Bool {
        dragSel.selectedItem != nil && rowDragState.draggingRowId == nil
    }

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                guard let item = dragSel.selectedItem else { return }
                withAnimation(.spring()) {
                    vm.moveItem(item, toRowId: rowId)
                    dragSel.selectedItem = nil
                }
            }
            .allowsHitTesting(isActive)
    }
}

// MARK: - RowDragOverlay
//
// 行ドラッグ中のビジュアルフィードバックを担う軽量ビュー。
// RowDragState の draggingRowId / targetRowId のみを購読する（低頻度）。
// dragLocation は購読しないため、ゴーストの位置更新では再描画されない。
//
// ── 表示ルール ──
//   ドラッグ中の行    : 半透明（opacity 0.4）
//   ドロップ先の行    : 上端に青い挿入インジケーター

private struct RowDragOverlay: View {
    let rowId: UUID
    @ObservedObject var rowDragState: RowDragState

    var body: some View {
        let isDragging = rowDragState.draggingRowId == rowId
        let isTarget   = rowDragState.targetRowId   == rowId

        ZStack(alignment: .top) {
            // ドラッグ中の行を半透明に
            if isDragging {
                Color.black.opacity(0.25)
                    .allowsHitTesting(false)
            }
            // ドロップ先に青い挿入ライン
            if isTarget {
                Rectangle()
                    .fill(Color.blue)
                    .frame(height: 3)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isDragging)
        .animation(.easeInOut(duration: 0.12), value: isTarget)
    }
}

// MARK: - TierRowView

struct TierRowView: View {

    let rowId: UUID
    @Binding var row: TierRow
    @ObservedObject var vm: TierListViewModel

    let dragPos: DragPositionState
    let dragHover: DragHoverState
    let dragSel: DragInteractionState
    // 行ドラッグ状態（let = TierRowView 本体は非購読、子ビューが各自購読）
    let rowDragState: RowDragState

    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var showEditSheet = false

    // ラベルドラッグ用ローカル状態
    @State private var labelLongPressTask: Task<Void, Never>? = nil
    @State private var isLabelDragging = false
    private let labelLongPressDuration: UInt64 = 400_000_000

    @Environment(\.tierTheme) private var tierTheme

    private var effectiveLabelSize: LabelSize   { vm.defaultLabelSize }
    private var effectiveTextSize: LabelTextSize { vm.defaultLabelTextSize }
    private var effectiveItemSize: ItemSize      { vm.defaultItemSize }

    private var labelColor: Color { Color(hex: row.color) }
    private var textColor:  Color { Color(hex: row.textColorHex) }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                tierLabel
                itemsArea
            }
            // 選択アイテム待機中のタップ領域（行ドラッグ中は非表示）
            RowTapOverlay(rowId: rowId, dragSel: dragSel, rowDragState: rowDragState, vm: vm)
        }
        .clipped()
        .overlay {
            RowBorder(rowId: rowId, dragHover: dragHover, dragSel: dragSel)
        }
        .overlay {
            // 行ドラッグのビジュアルフィードバック
            RowDragOverlay(rowId: rowId, rowDragState: rowDragState)
        }
        .sheet(isPresented: $showEditSheet) {
            TierRowEditSheet(row: $row, vm: vm)
        }
        .onDisappear {
            labelLongPressTask?.cancel()
            labelLongPressTask = nil
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

        return ZStack {
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
                        dragHover: dragHover,
                        dragSel: dragSel,
                        trayFrame: trayFrame
                    )
                    .frame(
                        width: effectiveItemSize.width,
                        height: effectiveItemSize.height
                    )
                }
            }
            .padding(4)

            // 選択待機中かつアイテムが空の行にプレースホルダーを表示
            if dragSel.selectedItem != nil && row.items.isEmpty {
                EmptyRowPlaceholder()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background {
            RowHoverBackground(rowId: rowId, dragHover: dragHover, tierTheme: tierTheme)
        }
        .animation(.spring(), value: dragSel.selectedItem == nil)
        .onDrop(of: [.text], isTargeted: nil) { _ in false }
    }

    // MARK: - ラベルView
    //
    // ── ジェスチャー設計 ──
    //   タップ（短押し）        → 編集シートを開く
    //   長押し（400ms）+ ドラッグ → 行の並び替え
    //
    // DragGesture(minimumDistance: 0) で両方を1つのジェスチャーで処理する。
    // onEnded 時に isLabelDragging が false なら「タップ」と判定。
    //
    // ドラッグヒント：ラベル右端に三本線アイコンを表示。
    // ドラッグ中のラベル自体は RowDragOverlay が半透明化する。

    private var tierLabel: some View {
        ZStack(alignment: .trailing) {
            Text(row.tierName)
                .font(tierTheme.fontStyle.font(size: effectiveTextSize.fontSize))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: effectiveLabelSize.width)
                .frame(maxHeight: .infinity)
                .background(labelColor)
                .foregroundColor(textColor)

            // ドラッグ可能を示すハンドルアイコン（右端に小さく表示）
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textColor.opacity(0.5))
                .padding(.trailing, 4)
        }
        .gesture(labelDragGesture)
    }

    // MARK: - ラベルドラッグジェスチャー

    private var labelDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                // 長押しタスクをまだ起動していなければ起動
                if labelLongPressTask == nil {
                    labelLongPressTask = Task { @MainActor in
                        do {
                            try await Task.sleep(nanoseconds: labelLongPressDuration)
                            guard !isLabelDragging else { return }
                            isLabelDragging = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring()) {
                                rowDragState.draggingRowId = rowId
                            }
                        } catch {}
                    }
                }

                guard isLabelDragging else { return }

                // ゴーストビューの位置を更新
                rowDragState.dragLocation = value.location

                // ホバー中の行を特定（自分自身は除く）
                rowDragState.targetRowId = rowFrames
                    .filter { $0.key != rowId }
                    .first(where: { $0.value.contains(value.location) })?
                    .key
            }
            .onEnded { _ in
                labelLongPressTask?.cancel()
                labelLongPressTask = nil

                if isLabelDragging {
                    // 行の並び替えを確定
                    if let targetId = rowDragState.targetRowId {
                        withAnimation(.spring()) {
                            vm.moveRow(fromId: rowId, toId: targetId)
                        }
                    }
                    isLabelDragging = false
                    withAnimation(.spring()) {
                        rowDragState.draggingRowId = nil
                        rowDragState.targetRowId   = nil
                    }
                } else {
                    // 長押し未満 = タップ → 編集シートを開く
                    showEditSheet = true
                }
            }
    }

}

// MARK: - EmptyRowPlaceholder
//
// アイテム選択待機中に、アイテムが空の行へ配置を促すプレースホルダー。
// 表示判定は親（itemsArea）が行い、このビュー自体は見た目のみを担う。

private struct EmptyRowPlaceholder: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle")
                .font(.caption.bold())
            Text("ここに配置")
                .font(.caption.bold())
        }
        .foregroundColor(.blue.opacity(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
