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

struct ContentView: View {
    @StateObject var vm = TierListViewModel()

    // シート・モーダル
    @State private var showAddItem = false
    @State private var showPool = false
    @State private var showTableEdit = false
    @State private var showItemEdit = false
    @State private var showAddHub = false  // ＋ハブメニュー

    // アイテム操作
    @State private var selectedItem: TierItem? = nil
    @State private var draggingItem: TierItem? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var hoveredRowId: UUID? = nil

    // フレーム
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var trayFrame: CGRect = .zero

    // タイトル編集
    @State private var tierListTitle = "ティア表"
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
                                        selectedItem: $selectedItem,
                                        draggingItem: $draggingItem,
                                        dragLocation: $dragLocation,
                                        hoveredRowId: $hoveredRowId,
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

                    // ── 背景ディム（プール） ──
                    if showPool {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    showPool = false
                                }
                            }
                            .zIndex(2)
                    }

                    // ── 未分類プールパネル ──
                    if showPool {
                        ItemPoolView(
                            vm: vm,
                            showAddItem: $showAddItem,
                            showPool: $showPool,
                            selectedItem: $selectedItem,
                            draggingItem: $draggingItem,
                            dragLocation: $dragLocation,
                            hoveredRowId: $hoveredRowId,
                            rowFrames: rowFrames,
                            trayFrame: trayFrame
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom),
                            removal: .offset(y: 500)
                        ))
                        .zIndex(3)
                    }

                    // ── 待機状態：アイテム表示 ──
                    if let item = selectedItem {
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

                    // ── ＋ハブのサブボタン（待機・ドラッグ中は非表示） ──
                    if showAddHub && selectedItem == nil && draggingItem == nil {
                        HStack {
                            VStack(alignment: .leading, spacing: 12) {
                                // アイテム追加
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

                                // 行追加
                                Button {
                                    withAnimation(.spring()) { showAddHub = false }
                                    let isFull = vm.rows.count >= 8
                                    if !isFull { vm.addRow() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.rectangle")
                                            .font(.title3.bold())
                                            .frame(width: 50, height: 50)
                                            .background(vm.rows.count >= 8 ? Color(.systemGray3) : Color.blue)
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
                        // 左：＋ハブボタン（待機・ドラッグ・プール中は非表示）
                        if selectedItem == nil && draggingItem == nil && !showPool {
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
                        } else if !showPool {
                            Color.clear
                                .frame(width: 50, height: 50)
                                .padding(.leading, 20)
                        } else {
                            Color.clear
                                .frame(width: 50, height: 50)
                                .padding(.leading, 20)
                        }

                        Spacer()

                        // 右：トレイボタン（常に表示）
                        Button {
                            if selectedItem != nil {
                                withAnimation(.spring()) {
                                    vm.returnToPool(selectedItem!)
                                    selectedItem = nil
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
                                        selectedItem != nil || draggingItem != nil
                                            ? Color.orange
                                            : showPool ? Color.orange : Color.blue
                                    )
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)

                                if !vm.pool.isEmpty && selectedItem == nil && draggingItem == nil {
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
                    .padding(.bottom, 36)
                    .zIndex(6)

                    // ── ドラッグ中のフローティングアイテム ──
                    if let item = draggingItem {
                        TierItemView(item: item)
                            .scaleEffect(1.15)
                            .shadow(color: .black.opacity(0.3), radius: 8)
                            .position(
                                x: dragLocation.x - geo.frame(in: .global).minX,
                                y: dragLocation.y - geo.frame(in: .global).minY
                            )
                            .allowsHitTesting(false)
                            .zIndex(99)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ── 左：戻るボタン（ホーム） ──
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 後ほど実装
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
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

                // ── 右：保存（プレビュー）＋ 設定 ──
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        // 後ほど実装（保存・プレビュー）
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                    }

                    Button {
                        showTableEdit = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemSheet(vm: vm)
            }
            .sheet(isPresented: $showItemEdit, onDismiss: {
                if let item = selectedItem {
                    selectedItem = latestItem(for: item)
                }
            }) {
                if let item = selectedItem {
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
    ContentView()
}
