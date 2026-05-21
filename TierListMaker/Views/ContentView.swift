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
    @State private var showAddItem = false
    @State private var showPool = false
    @State private var selectedItem: TierItem? = nil
    @State private var showItemEdit = false
    @State private var tierListTitle = "ティア表"
    @State private var isEditingTitle = false
    @State private var showTableEdit = false
    @FocusState private var titleFocused: Bool

    @State private var draggingItem: TierItem? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var rowFrames: [UUID: CGRect] = [:]
    @State private var hoveredRowId: UUID? = nil
    @State private var trayFrame: CGRect = .zero  // トレイボタンのフレーム

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
                                // スクロール余白
                                Color.clear.frame(height: 20)
                            }
                        }
                        .onPreferenceChange(RowFramePreferenceKey.self) { frames in
                            rowFrames = frames
                        }
                        // フローティングボタン(100pt) + フェード開始位置を考慮した表示領域
                        .frame(height: scrollGeo.size.height - 100)
                        // 下端をグラデーションでぼかす
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

                    // ── 背景ディム ──
                    if showPool {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .transition(.opacity)
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
                        .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .bottom),
                                        removal: .offset(y: 500)
                                    )
                                )
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
                                        // selectedItem から最新データを取得して表示
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

                    // ── フローティングボタン（待機・ドラッグ中はトレイのみ） ──
                    HStack {
                        if selectedItem == nil && draggingItem == nil {
                            // 左：表全体編集ボタン（プール表示中は非表示）
                            if !showPool {
                                Button {
                                    showTableEdit = true
                                } label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title2.bold())
                                        .frame(width: 50, height: 50)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding(.leading, 20)
                                .transition(.opacity.combined(with: .scale))
                            } else {
                                Color.clear
                                    .frame(width: 50, height: 50)
                                    .padding(.leading, 20)
                            }

                            Spacer()

                            // 中：行追加ボタン（プール表示中は非表示）
                            if !showPool {
                                let isFull = vm.rows.count >= 8
                                Button {
                                    if !isFull { vm.addRow() }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.title2.bold())
                                        .frame(width: 50, height: 50)
                                        .background(isFull ? Color(.systemGray3) : Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .disabled(isFull)
                                .transition(.opacity.combined(with: .scale))
                            } else {
                                Color.clear.frame(width: 50, height: 50)
                            }

                            Spacer()
                        } else {
                            Color.clear
                                .frame(width: 50, height: 50)
                                .padding(.leading, 20)
                            Spacer()
                            Color.clear.frame(width: 50, height: 50)
                            Spacer()
                        }

                        // 右：トレイボタン（常に表示）
                        Button {
                            if selectedItem != nil {
                                withAnimation(.spring()) {
                                    vm.returnToPool(selectedItem!)
                                    selectedItem = nil
                                }
                            } else {
                                withAnimation(.spring()) { showPool.toggle() }
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
                                Color.clear.onAppear {
                                    trayFrame = trayGeo.frame(in: .global)
                                }.onChange(of: trayGeo.frame(in: .global)) { newFrame in
                                    trayFrame = newFrame
                                }
                            }
                        )
                    }
                    .padding(.bottom, 36)
                    .zIndex(5)

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
                                        tierListTitle = String(
                                            newValue.prefix(maxTitleLength)
                                        )
                                    }
                                }
                                .frame(maxWidth: 160)
                            Button {
                                finishEditing()
                            } label: {
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
            }
            .sheet(isPresented: $showAddItem) {
                AddItemSheet(vm: vm)
            }
            // sheet
            .sheet(isPresented: $showItemEdit, onDismiss: {
                // 編集後に selectedItem を最新データで更新
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
    
    // vm から最新のアイテムデータを取得するヘルパー
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
