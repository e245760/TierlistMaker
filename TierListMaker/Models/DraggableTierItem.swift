import SwiftUI

struct DraggableTierItem: View {
    let item: TierItem
    @ObservedObject var vm: TierListViewModel
    let rowFrames: [UUID: CGRect]
    let onTap: () -> Void

    // 毎フレーム更新される位置を購読
    @ObservedObject var dragPos: DragPositionState
    // 低頻度の操作状態を購読
    @ObservedObject var dragSel: DragInteractionState

    var trayFrame: CGRect

    @State private var pressStartTime: Date? = nil
    @State private var isDragging = false

    private let longPressDuration = 0.4

    var isDraggingThis: Bool { dragSel.draggingItem?.id == item.id }

    var body: some View {
        TierItemView(item: item)
            .opacity(isDraggingThis ? 0.3 : 1.0)
            .scaleEffect(isDraggingThis ? 0.9 : 1.0)
            .animation(.spring(), value: isDraggingThis)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if pressStartTime == nil {
                            let startTime = Date()
                            pressStartTime = startTime

                            DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration) {
                                guard self.pressStartTime == startTime, !self.isDragging else { return }
                                self.isDragging = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring()) { self.dragSel.draggingItem = self.item }
                            }
                        }

                        if isDragging {
                            dragPos.dragLocation = value.location
                            if trayFrame.contains(value.location) {
                                dragSel.hoveredRowId = nil
                            } else {
                                dragSel.hoveredRowId = rowFrames.first(where: {
                                    $0.value.contains(value.location)
                                })?.key
                            }
                        }
                    }
                    .onEnded { value in
                        pressStartTime = nil

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
                                dragSel.hoveredRowId = nil
                            }
                        } else {
                            // シングルタップ
                            onTap()
                        }
                    }
            )
    }
}
