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
    let dragHover: DragHoverState
    let rowDragState: RowDragState
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
                            dragHover: dragHover,
                            dragSel: dragSel,
                            rowDragState: rowDragState,
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
    let dragHover: DragHoverState
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
                        dragHover: dragHover,
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
        dragHover: DragHoverState,
        rowFrames: [UUID: CGRect],
        trayFrame: CGRect
    ) -> some View {
        modifier(ItemPoolOverlay(
            vm: vm,
            showPool: showPool,
            dragPos: dragPos,
            dragSel: dragSel,
            dragHover: dragHover,
            rowFrames: rowFrames,
            trayFrame: trayFrame
        ))
    }
}

// MARK: - ドラッグ Ghost View（アイテム）
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

// MARK: - 行ドラッグ Ghost View
//
// RowDragState（dragLocation は高頻度）のみを購読する独立ビュー。
// TierRowView 本体を再描画させないために切り出す。
// ラベル部分だけをゴーストとして指先に追従させる。

private struct RowDragGhostView: View {
    @ObservedObject var rowDragState: RowDragState
    let vm: TierListViewModel
    let rows: [TierRow]
    let geoMinX: CGFloat
    let geoMinY: CGFloat

    @Environment(\.tierTheme) private var tierTheme

    var body: some View {
        if let id = rowDragState.draggingRowId,
           let row = rows.first(where: { $0.id == id }) {
            Text(row.tierName)
                .font(tierTheme.fontStyle.font(size: vm.defaultLabelTextSize.fontSize))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: vm.defaultLabelSize.width, height: 65)
                .background(Color(hex: row.color))
                .foregroundColor(Color(hex: row.textColorHex))
                .scaleEffect(1.08)
                .shadow(color: .black.opacity(0.35), radius: 10)
                .position(
                    x: rowDragState.dragLocation.x - geoMinX,
                    y: rowDragState.dragLocation.y - geoMinY
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
    @State private var showExportSheet = false

    // MARK: - タイトル編集
    // ★ 旧: isEditingTitle / finishEditing() / onChange(of: title) がここにあった
    // → TierEditToolbar に移譲。TierEditView が持つのは State と FocusState のみ。

    @State private var isEditingTitle = false
    @FocusState private var titleFocused: Bool
    private let maxTitleLength = 20

    // MARK: - ドラッグ状態

    @StateObject private var dragPos = DragPositionState()
    @StateObject private var dragSel = DragInteractionState()
    @StateObject private var dragHover = DragHoverState()
    @StateObject private var rowDragState = RowDragState()

    // MARK: - フレーム

    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var trayFrame: CGRect = .zero

    // MARK: - ライフサイクル

    @Environment(\.scenePhase) private var scenePhase

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
                        dragHover: dragHover,
                        rowDragState: rowDragState,
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

                    // ── ドラッグ Ghost（アイテム）──

                    DragGhostView(
                        dragPos: dragPos,
                        dragSel: dragSel,
                        geoMinX: geo.frame(in: .global).minX,
                        geoMinY: geo.frame(in: .global).minY
                    )
                    .zIndex(99)

                    // ── ドラッグ Ghost（行）──

                    RowDragGhostView(
                        rowDragState: rowDragState,
                        vm: vm,
                        rows: vm.rows,
                        geoMinX: geo.frame(in: .global).minX,
                        geoMinY: geo.frame(in: .global).minY
                    )
                    .environment(\.tierTheme, vm.tierTheme)
                    .zIndex(98)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                TierEditToolbar(
                    title: $tierListTitle,
                    isEditing: $isEditingTitle,
                    focused: $titleFocused,
                    maxLength: maxTitleLength,
                    onBack:     { saveAndDismiss() },
                    onExport:   { openExport() },
                    onSettings: { showTableEdit = true }
                )
            }
            .onChange(of: scenePhase) { phase in
                // バックグラウンド移行時に自動保存
                // 戻るボタン・エクスポートとは独立して動作する
                if phase == .background {
                    autoSave()
                }
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
            .sheet(isPresented: $showExportSheet) {
                TierExportSheet(vm: vm, title: normalizedTitle)
            }
        }
        .itemPoolOverlay(
            vm: vm,
            showPool: $showPool,
            dragPos: dragPos,
            dragSel: dragSel,
            dragHover: dragHover,
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

    /// バックグラウンド移行時の自動保存。
    /// 戻るボタンによる保存と処理は同じだが、画面遷移は行わない。
    private func autoSave() {
        let data = vm.toSaveData(
            id: saveId,
            title: normalizedTitle,
            createdAt: createdAt
        )
        onSave(data)
    }

    private func openExport() {
        let data = vm.toSaveData(
            id: saveId,
            title: normalizedTitle,
            createdAt: createdAt
        )
        onSave(data)
        showExportSheet = true
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
