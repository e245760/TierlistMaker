import SwiftUI

struct RowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(
        value: inout [UUID: CGRect],
        nextValue: () -> [UUID: CGRect]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - TierRowListView
//
// ティア行の一覧を縦スクロールで表示するビュー。
// GeometryReader で利用可能な高さを測り、下端フェードマスクをかける。
// 各行のグローバルフレームは RowFramePreferenceKey 経由で
// onRowFramesChanged コールバックにより親（TierEditView）へ通知する。
//
// dragPos / dragSel は自身の再描画に使わず TierRowView へ渡すだけなので let で保持する。
// TierRowView 側が @ObservedObject で購読するため、ここでの購読は不要。

private struct TierRowListView: View {
    @ObservedObject var vm: TierListViewModel
    let dragPos: DragPositionState
    let dragSel: DragInteractionState
    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect
    let onRowFramesChanged: ([UUID: CGRect]) -> Void

    var body: some View {
        GeometryReader { scrollGeo in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($vm.rows) { $row in
                        TierRowView(
                            rowId: row.id,
                            row: $row,
                            vm: vm,
                            dragPos: dragPos,
                            dragSel: dragSel,
                            rowFrames: rowFrames,
                            trayFrame: trayFrame
                        )
                        .background(
                            GeometryReader { rowGeo in
                                Color.clear.preference(
                                    key: RowFramePreferenceKey.self,
                                    value: [row.id: rowGeo.frame(in: .global)]
                                )
                            }
                        )
                    }
                    Color.clear.frame(height: 20)
                }
            }
            .environment(\.colorScheme, vm.tierTheme.colorScheme)
            .onPreferenceChange(RowFramePreferenceKey.self, perform: onRowFramesChanged)
            .frame(height: scrollGeo.size.height - 100)
            .mask(
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
            )
        }
    }
}

// MARK: - ItemPoolOverlay
//
// プールパネル（ItemPoolView）とその背景ディムを画面下部に重ねる ViewModifier。
// showPool が true のとき:
//   - 全面に半透明ディムを表示し、タップで閉じる
//   - 画面下端から ItemPoolView をスライドイン
//
// dragPos / dragSel は参照型なので let で渡しても ItemPoolView 内で正しく動作する。

private struct ItemPoolOverlay: ViewModifier {
    let vm: TierListViewModel
    @Binding var showPool: Bool
    let dragPos: DragPositionState
    let dragSel: DragInteractionState
    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    func body(content: Content) -> some View {
        content
            .overlay {
                if showPool {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.22)) { showPool = false }
                        }
                }
            }
            .overlay(alignment: .bottom) {
                if showPool {
                    ItemPoolView(
                        vm: vm,
                        showPool: $showPool,
                        dragPos: dragPos,
                        dragSel: dragSel,
                        rowFrames: rowFrames,
                        trayFrame: trayFrame
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom),
                        removal: .offset(y: 500)
                    ))
                }
            }
    }
}

private extension View {
    func itemPoolOverlay(
        vm: TierListViewModel,
        showPool: Binding<Bool>,
        dragPos: DragPositionState,
        dragSel: DragInteractionState,
        rowFrames: [UUID: CGRect],
        trayFrame: CGRect
    ) -> some View {
        modifier(ItemPoolOverlay(
            vm: vm,
            showPool: showPool,
            dragPos: dragPos,
            dragSel: dragSel,
            rowFrames: rowFrames,
            trayFrame: trayFrame
        ))
    }
}

// MARK: - ドラッグ Ghost View
//
// dragPos（毎フレーム）と dragSel（ドラッグ開始/終了）を購読する。
// TierEditView.body から切り出すことで、dragLocation 変化が
// TierEditView 全体の再描画を引き起こさなくなる。

private struct DragGhostView: View {
    @ObservedObject var dragPos: DragPositionState
    @ObservedObject var dragSel: DragInteractionState
    let geoMinX: CGFloat
    let geoMinY: CGFloat

    var body: some View {
        if let item = dragSel.draggingItem {
            TierItemView(item: item)
                .scaleEffect(1.15)
                .shadow(color: .black.opacity(0.3), radius: 8)
                .position(
                    x: dragPos.dragLocation.x - geoMinX,
                    y: dragPos.dragLocation.y - geoMinY
                )
                .allowsHitTesting(false)
        }
    }
}

// MARK: - TierEditView

struct TierEditView: View {
    @ObservedObject var vm: TierListViewModel

    let saveId: UUID
    let createdAt: Date
    let onSave: (TierListSaveData) -> Void
    let onDismiss: () -> Void

    @State private var tierListTitle: String

    init(
        vm: TierListViewModel,
        saveId: UUID,
        initialTitle: String = "ティア表",
        createdAt: Date = Date(),
        onSave: @escaping (TierListSaveData) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.vm = vm
        self.saveId = saveId
        self.createdAt = createdAt
        self.onSave = onSave
        self.onDismiss = onDismiss
        self._tierListTitle = State(initialValue: initialTitle)
    }

    // MARK: - シート・モーダル

    @State private var showAddItem    = false
    @State private var showPool       = false
    @State private var showTableEdit  = false
    @State private var showItemEdit   = false
    @State private var showAddHub     = false
    @State private var showSavedFeedback = false

    // MARK: - タイトル編集
    // ★ 旧: isEditingTitle / finishEditing() / onChange(of: title) がここにあった
    // → TierEditToolbar に移譲。TierEditView が持つのは State と FocusState のみ。

    @State private var isEditingTitle = false
    @FocusState private var titleFocused: Bool
    private let maxTitleLength = 10

    // MARK: - ドラッグ状態

    @StateObject private var dragPos = DragPositionState()
    @StateObject private var dragSel = DragInteractionState()

    // MARK: - フレーム

    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var trayFrame: CGRect = .zero

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // ── メインコンテンツ ──

                    TierRowListView(
                        vm: vm,
                        dragPos: dragPos,
                        dragSel: dragSel,
                        rowFrames: rowFrames,
                        trayFrame: trayFrame,
                        onRowFramesChanged: { rowFrames = $0 }
                    )
                    .zIndex(0)

                    // ── ＋ハブ背景ディム ──
                    // ★ 旧: Color.black.opacity(0.3) + onTapGesture がインラインにあった
                    // → TierEditHubDim に切り出し

                    if showAddHub {
                        TierEditHubDim {
                            withAnimation(.spring()) { showAddHub = false }
                        }
                        .zIndex(2)
                    }

                    // ── 待機状態：選択アイテム表示 ──
                    // ★ 旧: HStack { Spacer() VStack { ... } Spacer() } がインラインにあった
                    // → TierSelectedItemOverlay に切り出し

                    if let item = dragSel.selectedItem {
                        TierSelectedItemOverlay(
                            item: vm.resolveLatest(item),
                            onEdit: { showItemEdit = true }
                        )
                        .zIndex(4)
                    }

                    // ── ＋ハブのサブボタン ──
                    // ★ 旧: HStack { VStack { Button × 2 } Spacer() } がインラインにあった
                    // → TierEditHubMenu に切り出し

                    if showAddHub && dragSel.selectedItem == nil && dragSel.draggingItem == nil {
                        TierEditHubMenu(
                            vm: vm,
                            onAddItem: {
                                withAnimation(.spring()) { showAddHub = false }
                                showAddItem = true
                            },
                            onAddRow: {
                                withAnimation(.spring()) { showAddHub = false }
                                vm.addRow()
                            }
                        )
                        .zIndex(5)
                    }

                    // ── フローティングボタン ──
                    // ★ 旧: HStack { addHubButton ... trayButton } がインラインにあった
                    // → TierEditFloatingButtons に切り出し

                    TierEditFloatingButtons(
                        vm: vm,
                        dragSel: dragSel,
                        showAddHub: $showAddHub,
                        showPool: $showPool,
                        onReturnToPool: {
                            withAnimation(.spring()) {
                                vm.returnToPool(dragSel.selectedItem!)
                                dragSel.selectedItem = nil
                            }
                        },
                        trayFrameChanged: { trayFrame = $0 }
                    )
                    .zIndex(6)

                    // ── 保存フィードバック ──
                    // ★ 旧: ZStack { Capsule ... HStack { checkmark ... } } がインラインにあった
                    // → TierSavedFeedback に切り出し

                    if showSavedFeedback {
                        TierSavedFeedback()
                            .padding(.bottom, 110)
                            .zIndex(10)
                    }

                    // ── ドラッグ Ghost ──

                    DragGhostView(
                        dragPos: dragPos,
                        dragSel: dragSel,
                        geoMinX: geo.frame(in: .global).minX,
                        geoMinY: geo.frame(in: .global).minY
                    )
                    .zIndex(99)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ★ 旧: ToolbarItem × 4 がインラインにあった
                // → TierEditToolbar に切り出し

                TierEditToolbar(
                    title: $tierListTitle,
                    isEditing: $isEditingTitle,
                    focused: $titleFocused,
                    maxLength: maxTitleLength,
                    onBack:     { saveAndDismiss() },
                    onSave:     { triggerSaveFeedback() },
                    onSettings: { showTableEdit = true }
                )
            }
            .environment(\.tierTheme, vm.tierTheme)
            .sheet(isPresented: $showAddItem) {
                AddItemSheet(vm: vm)
            }
            .sheet(isPresented: $showItemEdit, onDismiss: {
                if let item = dragSel.selectedItem {
                    dragSel.selectedItem = vm.resolveLatest(item)
                }
            }) {
                if let item = dragSel.selectedItem {
                    if let poolIdx = vm.poolIndex(for: item.id) {
                        TierItemEditSheet(item: $vm.pool[poolIdx])
                    } else if let rowIdx = vm.rowIndex(for: item.id),
                              let itemIdx = vm.itemIndex(for: item.id, in: rowIdx) {
                        TierItemEditSheet(item: $vm.rows[rowIdx].items[itemIdx])
                    }
                }
            }
            .sheet(isPresented: $showTableEdit) {
                TableEditSheet(vm: vm)
            }
        }
        .itemPoolOverlay(
            vm: vm,
            showPool: $showPool,
            dragPos: dragPos,
            dragSel: dragSel,
            rowFrames: rowFrames,
            trayFrame: trayFrame
        )
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        let data = vm.toSaveData(
            id: saveId,
            title: normalizedTitle,
            createdAt: createdAt
        )
        onSave(data)
        onDismiss()
    }

    private func triggerSaveFeedback() {
        let data = vm.toSaveData(
            id: saveId,
            title: normalizedTitle,
            createdAt: createdAt
        )
        onSave(data)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSavedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.25)) { showSavedFeedback = false }
        }
    }

    // MARK: - Helpers

    /// 空白のみのタイトルをデフォルト文字列に正規化する
    private var normalizedTitle: String {
        let t = tierListTitle.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "ティア表" : t
    }
}

// MARK: - Preview

#Preview {
    TierEditView(
        vm: TierListViewModel(),
        saveId: UUID(),
        initialTitle: "プレビュー",
        onSave: { _ in },
        onDismiss: {}
    )
}
