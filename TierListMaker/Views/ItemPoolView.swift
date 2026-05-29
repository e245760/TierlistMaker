import SwiftUI

struct ItemPoolView: View {
    @ObservedObject var vm: TierListViewModel
    @Binding var showPool: Bool

    // ItemPoolView 自身は dragPos/dragSel の値を描画に使わない。
    // DraggableTierItem に渡す参照として保持するだけなので、let で十分。
    let dragPos: DragPositionState
    let dragSel: DragInteractionState
    let dragHover: DragHoverState
    let rowFrames: [UUID: CGRect]
    let trayFrame: CGRect

    @State private var dragOffset: CGFloat = 0
    @State private var showClearAlert = false

    @Environment(\.tierTheme) private var tierTheme

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
                            if value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                withAnimation(.spring()) { showPool = false }
                            }
                            withAnimation(.spring()) { dragOffset = 0 }
                        }
                )

            HStack {
                Text("未分類").font(.headline)
                Spacer()
                if !vm.pool.isEmpty {
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption.bold())
                            Text("すべて削除")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .alert("未分類をすべて削除しますか？", isPresented: $showClearAlert) {
                Button("削除", role: .destructive) {
                    withAnimation(.spring()) { vm.clearPool() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("プール内の\(vm.pool.count)個のアイテムがすべて削除されます。この操作は取り消せません。")
            }

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
                                        dragSel.selectedItem = item
                                        showPool = false
                                    }
                                },
                                dragPos: dragPos,
                                dragHover: dragHover,
                                dragSel: dragSel,
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
            tierTheme.poolBackground.ignoresSafeArea(edges: .bottom)
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
