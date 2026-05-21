//
//  DraggableTierItem.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/20.
//

import SwiftUI

struct DraggableTierItem: View {
    let item: TierItem
    @ObservedObject var vm: TierListViewModel
    let rowFrames: [UUID: CGRect]
    let onTap: () -> Void
    @Binding var draggingItem: TierItem?
    @Binding var dragLocation: CGPoint
    @Binding var hoveredRowId: UUID?
    @Binding var selectedItem: TierItem?
    var trayFrame: CGRect  // トレイボタンのフレーム

    @State private var pressStartTime: Date? = nil
    @State private var isDragging = false

    private let longPressDuration = 0.4

    var isDraggingThis: Bool { draggingItem?.id == item.id }

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
                                guard pressStartTime == startTime, !isDragging else { return }
                                isDragging = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring()) { draggingItem = item }
                            }
                        }

                        if isDragging {
                            dragLocation = value.location

                            // トレイの上にホバー中かチェック
                            if trayFrame.contains(value.location) {
                                hoveredRowId = nil
                            } else {
                                hoveredRowId = rowFrames.first(where: {
                                    $0.value.contains(value.location)
                                })?.key
                            }
                        }
                    }
                    .onEnded { value in
                        pressStartTime = nil

                        if isDragging {
                            // ── ドラッグ終了 ──
                            if trayFrame.contains(value.location) {
                                // トレイにドロップ → 未分類に戻す
                                withAnimation(.spring()) {
                                    vm.returnToPool(item)
                                }
                            } else if let targetId = rowFrames.first(where: {
                                $0.value.contains(value.location)
                            })?.key {
                                // ティア行にドロップ → 移動
                                withAnimation(.spring()) { vm.moveItem(item, toRowId: targetId) }
                            }
                            isDragging = false
                            withAnimation(.spring()) {
                                draggingItem = nil
                                hoveredRowId = nil
                            }
                        } else {
                            // ── タップ終了 ──
                            onTap()
                        }
                    }
            )
    }
}
