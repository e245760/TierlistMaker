import SwiftUI

// MARK: - TierEditFloatingButtons
//
// 画面下部に浮かぶ2つのフローティングボタンを担うビュー。
//
// ── 左：＋ボタン ──
//   ・選択/ドラッグ中・プール表示中は非表示
//   ・タップで showAddHub をトグル（ハブ開閉）
//
// ── 右：トレイボタン ──
//   ・プール表示中は非表示
//   ・アイテム選択中：タップで onReturnToPool を呼びプールに戻す
//   ・通常時：タップでプールを開閉
//   ・プール件数バッジを表示

struct TierEditFloatingButtons: View {
    @ObservedObject var vm: TierListViewModel
    @ObservedObject var dragSel: DragInteractionState
    @Binding var showAddHub: Bool
    @Binding var showPool: Bool

    /// アイテムをプールに戻す（選択状態の解除も含む）
    let onReturnToPool: () -> Void
    /// トレイボタンのフレームが確定・更新されたときに呼ばれる
    let trayFrameChanged: (CGRect) -> Void

    var body: some View {
        HStack {
            addHubButton
            Spacer()
            trayButton
        }
        .padding(.bottom, 36)
    }

    // MARK: - ＋ボタン

    @ViewBuilder
    private var addHubButton: some View {
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
            // 右のトレイボタンを右端に保つためのスペーサー代わり
            Color.clear
                .frame(width: 50, height: 50)
                .padding(.leading, 20)
        }
    }

    // MARK: - トレイボタン

    @ViewBuilder
    private var trayButton: some View {
        if !showPool {
            Button {
                if dragSel.selectedItem != nil {
                    onReturnToPool()
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
                        .background(trayBackgroundColor)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)

                    // プール件数バッジ（選択/ドラッグ中は非表示）
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
            // trayFrame 計測：ドラッグのドロップ判定に使う
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear       { trayFrameChanged(geo.frame(in: .global)) }
                        .onChange(of: geo.frame(in: .global)) { trayFrameChanged($0) }
                }
            )
        }
    }

    // MARK: - Tray Background Color

    private var trayBackgroundColor: Color {
        if dragSel.selectedItem != nil || dragSel.draggingItem != nil {
            return .orange   // 選択/ドラッグ中：「戻す」アクションを示すオレンジ
        }
        return showPool ? .orange : .blue
    }
}
