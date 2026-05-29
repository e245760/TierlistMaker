import SwiftUI

// MARK: - TierSelectedItemOverlay
//
// アイテムをタップ選択したあと「配置先のティアをタップ」という
// 待機状態を示すオーバーレイ。
//
// 呼び出し元（TierEditView）で latestItem(for:) を解決した最新の
// TierItem を渡すこと。このビュー自体はデータ解決を行わない。

struct TierSelectedItemOverlay: View {
    let item: TierItem
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Spacer()
                .allowsHitTesting(false)
            VStack(spacing: 6) {
                Text("配置先のティアをタップ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .allowsHitTesting(false)

                Button(action: onEdit) {
                    ZStack(alignment: .topTrailing) {
                        TierItemView(item: item)

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
                    .allowsHitTesting(false)
            }
            Spacer()
                .allowsHitTesting(false)
        }
        .padding(.bottom, 36)
        .transition(.opacity.combined(with: .scale))
    }
}
