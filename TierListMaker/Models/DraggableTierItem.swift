import SwiftUI

struct DraggableTierItem: View {
    let item: TierItem
    @ObservedObject var vm: TierListViewModel
    let rowFrames: [UUID: CGRect]
    let onTap: () -> Void

    // 書き込み専用（前回の修正で let 化済み）
    let dragPos: DragPositionState
    // hoveredRowId の書き込み先（新規追加）
    let dragHover: DragHoverState
    // draggingItem / selectedItem の読み取りが必要なので @ObservedObject を維持
    @ObservedObject var dragSel: DragInteractionState

    var trayFrame: CGRect

    @State private var longPressTask: Task<Void, Never>? = nil
    @State private var isDragging = false

    private let longPressDuration: UInt64 = 400_000_000

    var isDraggingThis: Bool { dragSel.draggingItem?.id == item.id }
    /// 行内でタップ選択されたアイテムを半透明にする（TierRowView.itemsArea から移動）
    var isSelectedItem: Bool { dragSel.selectedItem?.id == item.id }

    var body: some View {
        TierItemView(item: item)
            .opacity(isDraggingThis || isSelectedItem ? 0.3 : 1.0)
            .scaleEffect(isDraggingThis ? 0.9 : 1.0)
            .animation(.spring(), value: isDraggingThis)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if longPressTask == nil {
                            longPressTask = Task { @MainActor in
                                do {
                                    try await Task.sleep(nanoseconds: longPressDuration)
                                    guard !isDragging else { return }
                                    isDragging = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring()) { dragSel.draggingItem = item }
                                } catch {}
                            }
                        }

                        if isDragging {
                            dragPos.dragLocation = value.location
                            // dragSel.hoveredRowId → dragHover.hoveredRowId に変更
                            if trayFrame.contains(value.location) {
                                dragHover.hoveredRowId = nil
                            } else {
                                dragHover.hoveredRowId = rowFrames.first(where: {
                                    $0.value.contains(value.location)
                                })?.key
                            }
                        }
                    }
                    .onEnded { value in
                        longPressTask?.cancel()
                        longPressTask = nil

                        if isDragging {
                            if trayFrame.contains(value.location) {
                                withAnimation(.spring()) { vm.returnToPool(item) }
                            } else if let targetId = rowFrames.first(where: {
                                $0.value.contains(value.location)
                            })?.key {
                                withAnimation(.spring()) { vm.moveItem(item, toRowId: targetId) }
                            }
                            isDragging = false
                            withAnimation(.spring()) {
                                dragSel.draggingItem = nil
                                dragHover.hoveredRowId = nil  // dragSel → dragHover
                            }
                        } else {
                            onTap()
                        }
                    }
            )
            .onDisappear {
                longPressTask?.cancel()
                longPressTask = nil
            }
    }
}
