//
//  TierRowView.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/18.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct TierRowView: View {
    @Binding var row: TierRow
    @ObservedObject var vm: TierListViewModel
    @Binding var selectedItem: TierItem?
    @Binding var draggingItem: TierItem?
    @Binding var dragLocation: CGPoint
    @Binding var hoveredRowId: UUID?
    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var showEditSheet = false
    private var isHovered: Bool { hoveredRowId == row.id }

    var body: some View {
        ZStack(alignment: .trailing) {

            // ── 行本体 ──
            HStack(spacing: 0) {

                // ── ティアラベル ──
                Text(row.tierName)
                    .font(.system(size: row.labelTextSize.fontSize, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: row.labelSize.width)
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: row.color))
                    .foregroundColor(.black)
                    .onTapGesture(count: 2) {
                        showEditSheet = true
                    }
                    .contextMenu {
                        Button { showEditSheet = true } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            withAnimation(.spring()) { vm.removeRow(id: row.id) }
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    } preview: {
                        HStack(spacing: 0) {
                            Text(row.tierName)
                                .font(.system(size: row.labelTextSize.fontSize, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: row.labelSize.width)
                                .frame(maxHeight: .infinity)
                                .background(Color(hex: row.color))
                                .foregroundColor(.black)
                            LazyHStack(spacing: 4) {
                                ForEach(row.items) { item in
                                    TierItemView(item: item)
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .background(Color(.systemGray6))
                        }
                        .frame(width: UIScreen.main.bounds.width, height: 70)
                    }

                // ── アイテムエリア ──
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) {
                        ForEach(row.items) { item in
                            DraggableTierItem(
                                item: item,
                                vm: vm,
                                rowFrames: rowFrames,
                                onTap: {
                                    withAnimation(.spring()) {
                                        selectedItem = item
                                    }
                                },
                                draggingItem: $draggingItem,
                                dragLocation: $dragLocation,
                                hoveredRowId: $hoveredRowId,
                                selectedItem: $selectedItem,
                                trayFrame: trayFrame
                            )
                            .opacity(selectedItem?.id == item.id ? 0.3 : 1.0)
                            .animation(.spring(), value: selectedItem?.id == item.id)
                        }
                    }
                    .padding(4)
                    .frame(minHeight: 70)
                }
                .background(isHovered ? Color.blue.opacity(0.15) : Color(.systemGray6))
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            }

            // ── 待機状態のとき行全体をタップでアイテム配置 ──
            if selectedItem != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let item = selectedItem {
                            withAnimation(.spring()) {
                                vm.moveItem(item, toRowId: row.id)
                                selectedItem = nil
                            }
                        }
                    }
            }
        }
        .frame(minHeight: 70)
        .clipped()
        .border(
            isHovered ? Color.blue : (selectedItem != nil ? Color.blue.opacity(0.5) : Color.gray.opacity(0.3)),
            width: isHovered ? 2 : (selectedItem != nil ? 1.5 : 0.5)
        )
        .sheet(isPresented: $showEditSheet) {
            TierRowEditSheet(row: $row)
        }
    }
}
