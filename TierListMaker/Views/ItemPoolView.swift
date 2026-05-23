import SwiftUI

struct ItemPoolView: View {
    @ObservedObject var vm: TierListViewModel
    @Binding var showAddItem: Bool
    @Binding var showPool: Bool
    @Binding var selectedItem: TierItem?
    @Binding var draggingItem: TierItem?
    @Binding var dragLocation: CGPoint
    @Binding var hoveredRowId: UUID?
    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var dragOffset: CGFloat = 0

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
                            // 下方向のみ追従
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            // 一定距離以上で閉じる
                            if value.translation.height > 100 {
                                withAnimation(.spring()) {
                                    showPool = false
                                }
                            }

                            // 元位置へ戻す
                            withAnimation(.spring()) {
                                dragOffset = 0
                            }
                        }
                )

            HStack {
                Text("未分類")
                    .font(.headline)
                Spacer()
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

                            DraggableTierItem(
                                item: item,
                                vm: vm,
                                rowFrames: rowFrames,
                                onTap: {
                                    withAnimation(.spring()) {
                                        selectedItem = item
                                        showPool = false
                                    }
                                },
                                draggingItem: $draggingItem,
                                dragLocation: $dragLocation,
                                hoveredRowId: $hoveredRowId,
                                selectedItem: $selectedItem,
                                trayFrame: trayFrame
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
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
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
