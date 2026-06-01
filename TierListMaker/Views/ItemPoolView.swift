import SwiftUI

// MARK: - PoolDraggableItem
//
// プールパネル内のアイテムに長押し→ドラッグ→行へドロップを実装するビュー。
// DraggableTierItem（行内アイテム用）と同じジェスチャーロジックを使うが、
// ドラッグ開始時に isDraggingFromPool を true にしてパネルを透明化する点が異なる。
//
// ── ジェスチャー分岐 ──
//   短押し（長押し未満）: 選択状態にしてパネルを閉じる（既存のタップ動作）
//   長押し（400ms以上）: ドラッグ開始 → ゴースト表示 → 行にドロップ

private struct PoolDraggableItem: View {
    let item: TierItem
    @ObservedObject var vm: TierListViewModel
    let dragPos: DragPositionState
    let dragHover: DragHoverState
    @ObservedObject var dragSel: DragInteractionState
    let rowFrames: [UUID: CGRect]
    @Binding var showPool: Bool
    @Binding var isDraggingFromPool: Bool

    @State private var longPressTask: Task<Void, Never>? = nil
    @State private var isDragging = false

    private let longPressDuration: UInt64 = 400_000_000

    var isDraggingThis: Bool { dragSel.draggingItem?.id == item.id }

    var body: some View {
        TierItemView(item: item)
            .opacity(isDraggingThis ? 0.3 : 1.0)
            .scaleEffect(isDraggingThis ? 0.9 : 1.0)
            .animation(.spring(), value: isDraggingThis)
            .contentShape(Rectangle())
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
                                    withAnimation(.spring()) {
                                        dragSel.draggingItem = item
                                        isDraggingFromPool   = true
                                    }
                                } catch {}
                            }
                        }

                        if isDragging {
                            dragPos.dragLocation = value.location
                            dragHover.hoveredRowId = rowFrames.first(where: {
                                $0.value.contains(value.location)
                            })?.key
                        }
                    }
                    .onEnded { value in
                        longPressTask?.cancel()
                        longPressTask = nil

                        if isDragging {
                            // 行の上でドロップ → 移動して成功
                            if let targetId = rowFrames.first(where: {
                                $0.value.contains(value.location)
                            })?.key {
                                withAnimation(.spring()) { vm.moveItem(item, toRowId: targetId) }
                                // ドロップ成功後はパネルを閉じる
                                withAnimation(.easeOut(duration: 0.22)) { showPool = false }
                            }
                            // 行以外でドロップ（宙に離した）→ プールに留まる、フィードバックなし
                            isDragging = false
                            withAnimation(.spring()) {
                                dragSel.draggingItem = nil
                                dragHover.hoveredRowId = nil
                                isDraggingFromPool = false
                            }
                        } else {
                            // タップ（短押し）: 選択してパネルを閉じる
                            dragSel.selectedItem = item
                            withAnimation(.easeOut(duration: 0.15)) { showPool = false }
                        }
                    }
            )
            .onDisappear {
                longPressTask?.cancel()
                longPressTask = nil
                // ビューが消えた場合（アイテムが行へ移動した等）に状態をクリーン
                if isDragging {
                    isDragging = false
                    isDraggingFromPool = false
                    dragSel.draggingItem   = nil
                    dragHover.hoveredRowId = nil
                }
            }
    }
}

// MARK: - ItemPoolView

struct ItemPoolView: View {
    @ObservedObject var vm: TierListViewModel
    @Binding var showPool: Bool

    let dragSel: DragInteractionState
    // プールからのドラッグに必要な追加プロパティ
    let dragPos: DragPositionState
    let dragHover: DragHoverState
    let rowFrames: [UUID: CGRect]
    /// ドラッグ中はパネルを透明化するためのフラグ（TierEditView と共有）
    @Binding var isDraggingFromPool: Bool

    @State private var dragOffset: CGFloat = 0

    @Environment(\.tierTheme) private var tierTheme

    private let rows = Array(repeating: GridItem(.fixed(65), spacing: 6), count: 4)
    private let itemSize: CGFloat = 65
    private let rowCount: CGFloat = 4
    private let spacing: CGFloat = 6

    private var gridHeight: CGFloat {
        itemSize * rowCount + spacing * (rowCount - 1) + 16
    }

    var body: some View {
        VStack(spacing: 0) {

            // ハンドル
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                withAnimation(.spring()) { showPool = false }
                            }
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                )

            HStack {
                Text("未分類").font(.headline)
                Spacer()
                // すべて削除ボタンは現在非表示（機能は vm.clearPool() として残存）
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if vm.pool.isEmpty {
                Text("アイテムがありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: gridHeight)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: spacing) {
                        ForEach(vm.pool) { item in
                            PoolDraggableItem(
                                item: item,
                                vm: vm,
                                dragPos: dragPos,
                                dragHover: dragHover,
                                dragSel: dragSel,
                                rowFrames: rowFrames,
                                showPool: $showPool,
                                isDraggingFromPool: $isDraggingFromPool
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(height: gridHeight)
            }
        }
        .offset(y: dragOffset)
        .animation(.spring(), value: dragOffset)
        .background(
            tierTheme.poolBackground.ignoresSafeArea(edges: .bottom)
        )
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
