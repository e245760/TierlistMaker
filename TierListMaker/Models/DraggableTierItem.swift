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

    // Task を保持することでキャンセルが可能になる。
    // Date によるタイムスタンプ比較が不要になりコードもシンプルになる。
    @State private var longPressTask: Task<Void, Never>? = nil
    @State private var isDragging = false

    private let longPressDuration: UInt64 = 400_000_000  // 0.4秒（ナノ秒）

    var isDraggingThis: Bool { dragSel.draggingItem?.id == item.id }

    var body: some View {
        TierItemView(item: item)
            .opacity(isDraggingThis ? 0.3 : 1.0)
            .scaleEffect(isDraggingThis ? 0.9 : 1.0)
            .animation(.spring(), value: isDraggingThis)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        // タスクがなければ新規作成（指が触れた瞬間に1回だけ）
                        if longPressTask == nil {
                            longPressTask = Task { @MainActor in
                                do {
                                    try await Task.sleep(nanoseconds: longPressDuration)
                                    // sleep が正常完了 = キャンセルなし = ロングプレス成立
                                    guard !isDragging else { return }
                                    isDragging = true
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    withAnimation(.spring()) { dragSel.draggingItem = item }
                                } catch {
                                    // Task.CancellationError: 指が離れた or ビューが消えた
                                    // → 何もしない（正常なキャンセル）
                                }
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
                        // タスクをキャンセルして破棄
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
                                dragSel.hoveredRowId = nil
                            }
                        } else {
                            // シングルタップ
                            onTap()
                        }
                    }
            )
            .onDisappear {
                // ビューが消えた時も確実にキャンセル
                longPressTask?.cancel()
                longPressTask = nil
            }
    }
}
