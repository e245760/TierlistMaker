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

    // シート・モーダル
    @State private var showAddItem = false
    @State private var showPool = false
    @State private var showTableEdit = false
    @State private var showItemEdit = false
    @State private var showAddHub = false
    @State private var showSavedFeedback = false

    // ── ドラッグ状態（2つの ObservableObject に分離） ──
    //
    // dragPos: dragLocation のみ（毎フレーム更新）
    //   → TierEditView.body は dragPos を直接読まない。
    //     DragGhostView が独立して購読するため、
    //     dragLocation 変化で TierEditView 全体が再描画されない。
    //
    // dragSel: draggingItem / hoveredRowId / selectedItem（低頻度更新）
    //   → TierEditView.body は selectedItem と draggingItem を読む（選択UI制御）。
    //     これらはタップ・ドラッグ開始終了時のみ変化するため再描画頻度は低い。
    @StateObject private var dragPos = DragPositionState()
    @StateObject private var dragSel = DragInteractionState()

    // フレーム
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var trayFrame: CGRect = .zero

    // タイトル編集
    @State private var isEditingTitle = false
    @FocusState private var titleFocused: Bool

    private let maxTitleLength = 10

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // ── メインコンテンツ ──
                    GeometryReader { scrollGeo in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach($vm.rows) { $row in
                                    TierRowView(
                                        rowId: row.id,
                                        row: $row,
                                        vm: vm,
                                        dragPos: dragPos,   // let 渡し（購読なし）
                                        dragSel: dragSel,   // @ObservedObject 渡し
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
                        .onPreferenceChange(RowFramePreferenceKey.self) { frames in
                            rowFrames = frames
                        }
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
                    .zIndex(0)

                    // ── ＋ハブ背景ディム ──
                    if showAddHub {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring()) { showAddHub = false }
                            }
                            .zIndex(2)
                    }

                    // ── 待機状態：選択アイテム表示 ──
                    if let item = dragSel.selectedItem {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Text("配置先のティアをタップ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button {
                                    showItemEdit = true
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        TierItemView(item: latestItem(for: item) ?? item)
                                        Image(systemName: "pencil.circle.fill")
                                            .foregroundColor(.blue)
                                            .background(Color.white.clipShape(Circle()))
                                            .font(.subheadline)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                                .buttonStyle(.plain)
                                Text("タップして編集")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 36)
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(4)
                    }

                    // ── ＋ハブのサブボタン ──
                    if showAddHub && dragSel.selectedItem == nil && dragSel.draggingItem == nil {
                        HStack {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    withAnimation(.spring()) { showAddHub = false }
                                    showAddItem = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title3.bold())
                                            .frame(width: 50, height: 50)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                        Text("アイテムを追加")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                }

                                Button {
                                    withAnimation(.spring()) { showAddHub = false }
                                    let isFull = vm.rows.count >= 8
                                    if !isFull { vm.addRow() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.rectangle")
                                            .font(.title3.bold())
                                            .frame(width: 50, height: 50)
                                            .background(
                                                vm.rows.count >= 8
                                                    ? Color(.systemGray3)
                                                    : Color.blue
                                            )
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                            .shadow(radius: 4)
                                        Text(vm.rows.count >= 8 ? "行は最大8行です" : "行を追加")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                }
                                .disabled(vm.rows.count >= 8)
                            }
                            .padding(.leading, 20)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                            Spacer()
                        }
                        .padding(.bottom, 90)
                        .zIndex(5)
                    }

                    // ── フローティングボタン ──
                    HStack {
                        if dragSel.selectedItem == nil && dragSel.draggingItem == nil && !showPool {
                            Button {
                                withAnimation(.spring()) { showAddHub.toggle() }
                            } label: {
                                Image(systemName: showAddHub ? "xmark" : "plus")
                                    .font(.title2.bold())
                                    .frame(width: 50, height: 50)
                                    .background(showAddHub ? Color(.systemGray3) : Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                    .rotationEffect(.degrees(showAddHub ? 90 : 0))
                                    .animation(.spring(), value: showAddHub)
                            }
                            .padding(.leading, 20)
                            .transition(.opacity.combined(with: .scale))
                        } else {
                            Color.clear
                                .frame(width: 50, height: 50)
                                .padding(.leading, 20)
                        }

                        Spacer()

                        if !showPool {
                            Button {
                                if dragSel.selectedItem != nil {
                                    withAnimation(.spring()) {
                                        vm.returnToPool(dragSel.selectedItem!)
                                        dragSel.selectedItem = nil
                                    }
                                } else {
                                    withAnimation(.spring()) {
                                        showAddHub = false
                                        showPool.toggle()
                                    }
                                }
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: showPool ? "tray.fill" : "tray")
                                        .font(.title2.bold())
                                        .frame(width: 50, height: 50)
                                        .background(
                                            dragSel.selectedItem != nil || dragSel.draggingItem != nil
                                                ? Color.orange
                                                : showPool ? Color.orange : Color.blue
                                        )
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)

                                    if !vm.pool.isEmpty
                                        && dragSel.selectedItem == nil
                                        && dragSel.draggingItem == nil {
                                        Text("\(vm.pool.count)")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.trailing, 20)
                            .background(
                                GeometryReader { trayGeo in
                                    Color.clear
                                        .onAppear { trayFrame = trayGeo.frame(in: .global) }
                                        .onChange(of: trayGeo.frame(in: .global)) { newFrame in
                                            trayFrame = newFrame
                                        }
                                }
                            )
                        }
                    }
                    .padding(.bottom, 36)
                    .zIndex(6)

                    // ── 保存フィードバック ──
                    if showSavedFeedback {
                        ZStack {
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 140, height: 44)
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("保存しました")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 1.1).combined(with: .opacity)
                            )
                        )
                        .padding(.bottom, 110)
                        .zIndex(10)
                    }

                    // ── ドラッグ中のフローティング Ghost ──
                    // DragGhostView が dragPos を独立して購読するため、
                    // dragLocation 変化でこのbody全体が再描画されない。
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

                // ── 左：戻るボタン ──
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.body.bold())
                            Text("ライブラリ").font(.body)
                        }
                    }
                }

                // ── 中央：タイトル ──
                ToolbarItem(placement: .principal) {
                    if isEditingTitle {
                        HStack(spacing: 4) {
                            TextField("", text: $tierListTitle)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .focused($titleFocused)
                                .submitLabel(.done)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                                .onSubmit { finishEditing() }
                                .onChange(of: tierListTitle) { newValue in
                                    if newValue.count > maxTitleLength {
                                        tierListTitle = String(newValue.prefix(maxTitleLength))
                                    }
                                }
                                .frame(maxWidth: 160)
                            Button { finishEditing() } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(tierListTitle.isEmpty ? "ティア表" : tierListTitle)
                                .font(.headline)
                                .lineLimit(1)
                            Button {
                                isEditingTitle = true
                                titleFocused = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ── 右：保存 ＋ 設定 ──
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { triggerSaveFeedback() } label: {
                        Image(systemName: "square.and.arrow.down").font(.body)
                    }
                    Button { showTableEdit = true } label: {
                        Image(systemName: "gearshape").font(.body)
                    }
                }
            }
            .environment(\.tierTheme, vm.tierTheme)
            .sheet(isPresented: $showAddItem) {
                AddItemSheet(vm: vm)
            }
            .sheet(isPresented: $showItemEdit, onDismiss: {
                if let item = dragSel.selectedItem {
                    dragSel.selectedItem = latestItem(for: item)
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
                    showAddItem: $showAddItem,
                    showPool: $showPool,
                    dragPos: dragPos,   // let 渡し（購読なし）
                    dragSel: dragSel,   // let 渡し（購読なし、子に委ねる）
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

    // MARK: - Actions

    private func saveAndDismiss() {
        let title = tierListTitle.trimmingCharacters(in: .whitespaces)
        let data = vm.toSaveData(
            id: saveId,
            title: title.isEmpty ? "ティア表" : title,
            createdAt: createdAt
        )
        onSave(data)
        onDismiss()
    }

    private func triggerSaveFeedback() {
        let title = tierListTitle.trimmingCharacters(in: .whitespaces)
        let data = vm.toSaveData(
            id: saveId,
            title: title.isEmpty ? "ティア表" : title,
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

    private func finishEditing() {
        if tierListTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            tierListTitle = "ティア表"
        }
        isEditingTitle = false
        titleFocused = false
    }

    private func latestItem(for item: TierItem) -> TierItem? {
        if let poolIdx = vm.poolIndex(for: item.id) {
            return vm.pool[poolIdx]
        } else if let rowIdx = vm.rowIndex(for: item.id),
                  let itemIdx = vm.itemIndex(for: item.id, in: rowIdx) {
            return vm.rows[rowIdx].items[itemIdx]
        }
        return nil
    }
}

#Preview {
    TierEditView(
        vm: TierListViewModel(),
        saveId: UUID(),
        initialTitle: "プレビュー",
        onSave: { _ in },
        onDismiss: {}
    )
}
