import SwiftUI

// MARK: - TierEditHubDim
//
// ＋ハブが開いているときに表示する背景ディムオーバーレイ。
// タップで親に閉じる指示を返す。

struct TierEditHubDim: View {
    let onTap: () -> Void

    var body: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture(perform: onTap)
    }
}

// MARK: - TierEditHubMenu
//
// ＋ハブが開いているときに表示する「アイテム追加」「行追加」のサブボタン群。
// 行が上限（8行）に達している場合は行追加ボタンを無効化する。
// 各ボタンのタップは onAddItem / onAddRow コールバックで親に委譲し、
// このビュー自体はUIのみを担う。

struct TierEditHubMenu: View {
    @ObservedObject var vm: TierListViewModel
    let onAddItem: () -> Void
    let onAddRow: () -> Void

    private var isRowFull: Bool { vm.rows.count >= 8 }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                hubButton(
                    icon: "photo.badge.plus",
                    label: "アイテムを追加",
                    color: .blue,
                    action: onAddItem
                )

                hubButton(
                    icon: "plus.rectangle",
                    label: isRowFull ? "行は最大8行です" : "行を追加",
                    color: isRowFull ? Color(.systemGray3) : .blue,
                    action: onAddRow
                )
                .disabled(isRowFull)
            }
            .padding(.leading, 20)
            .padding(.bottom, 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            Spacer()
        }
        .padding(.bottom, 90)
    }

    // MARK: - Hub Button

    @ViewBuilder
    private func hubButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.bold())
                    .frame(width: 50, height: 50)
                    .background(color)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)

                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
            }
        }
    }
}
