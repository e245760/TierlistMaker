//
//  ContentView.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/18.
//

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
    @State private var tierListTitle = "ティア表"
    @State private var isEditingTitle = false
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
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach($vm.rows) { $row in
                                TierRowView(
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
                                            value: [
                                                row.id: rowGeo.frame(
                                                    in: .global
                                                )
                                            ]
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .onPreferenceChange(RowFramePreferenceKey.self) { frames in
                        rowFrames = frames
                    }
                    .zIndex(0)

                    // ── 背景ディム ──
                    if showPool {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring()) { showPool = false }
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
                        .transition(.move(edge: .bottom))
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
                                TierItemView(item: item)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 36)
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(4)
                    }

                    // ── フローティングボタン ──
                    HStack {
                        // ティア追加ボタン（待機中・ドラッグ中・プール表示中は非表示）
                        if !showPool && selectedItem == nil
                            && draggingItem == nil
                        {
                            let isFull = vm.rows.count >= 8
                            Button {
                                if !isFull { vm.addRow() }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .frame(width: 50, height: 50)
                                    .background(
                                        isFull
                                            ? Color(.systemGray3) : Color.blue
                                    )
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .disabled(isFull)
                            .padding(.leading, 20)
                            .transition(.opacity.combined(with: .scale))
                        } else {
                            // スペース確保用
                            Color.clear
                                .frame(width: 50, height: 50)
                                .padding(.leading, 20)
                        }

                        Spacer()

                        // トレイボタン（常に表示）
                        Button {
                            if selectedItem != nil {
                                // 待機中にタップ → 未分類に戻す
                                withAnimation(.spring()) {
                                    vm.returnToPool(selectedItem!)
                                    selectedItem = nil
                                }
                            } else {
                                withAnimation(.spring()) { showPool.toggle() }
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(
                                    systemName: showPool ? "tray.fill" : "tray"
                                )
                                .font(.title2.bold())
                                .frame(width: 50, height: 50)
                                .background(
                                    selectedItem != nil || draggingItem != nil
                                        ? Color.orange  // 待機中・ドラッグ中はオレンジ
                                        : showPool ? Color.orange : Color.blue
                                )
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)

                                if !vm.pool.isEmpty && selectedItem == nil
                                    && draggingItem == nil
                                {
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
                        // トレイボタンのフレームを取得
                        .background(
                            GeometryReader { trayGeo in
                                Color.clear.onAppear {
                                    trayFrame = trayGeo.frame(in: .global)
                                }.onChange(of: trayGeo.frame(in: .global)) {
                                    newFrame in
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
        }
    }

    private func finishEditing() {
        if tierListTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            tierListTitle = "ティア表"
        }
        isEditingTitle = false
        titleFocused = false
    }
}

#Preview {
    ContentView()
}
