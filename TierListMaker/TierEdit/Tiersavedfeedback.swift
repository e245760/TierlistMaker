// 消してよし

import SwiftUI

// MARK: - TierSavedFeedback
//
// 保存完了時に一時表示するトーストUI。
// 表示トリガー・非表示タイマーは呼び出し元（TierEditView）が管理し、
// このビューは isPresented に応じた見た目のみを担う。
//
// 使い方:
//   if showSavedFeedback {
//       TierSavedFeedback()
//           .padding(.bottom, 110)
//           .zIndex(10)
//   }

struct TierSavedFeedback: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.7))
                .frame(width: 140, height: 44)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("保存しました")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
        }
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal:   .scale(scale: 1.1).combined(with: .opacity)
            )
        )
    }
}
