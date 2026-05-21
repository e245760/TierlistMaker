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

    private let rows = Array(repeating: GridItem(.fixed(65), spacing: 6), count: 4)
    private let itemSize: CGFloat = 65
    private let rowCount: CGFloat = 4
    private let spacing: CGFloat = 6

    private var gridHeight: CGFloat {
        itemSize * rowCount + spacing * (rowCount - 1) + 16
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            HStack {
                Text("未分類")
                    .font(.headline)
                Spacer()
                Button {
                    showAddItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
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
                                    }
                                    showPool = false
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
        // 上だけ角丸をcornerRadiusで実現
        .background(Color(.systemBackground))
        .cornerRadius(20, antialiased: true)
        .shadow(color: .black.opacity(0.15), radius: 12, y: -4)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // セーフエリアまで背景を伸ばす（clipの外側）
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
