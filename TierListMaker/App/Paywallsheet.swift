import SwiftUI
import StoreKit

// MARK: - PaywallSheet
//
// 無料上限（5個）に達したときに表示するペイウォールシート。
// PurchaseManager を受け取り、購入・復元処理を行う。
// 購入成功または復元成功でシートを自動的に閉じる。

struct PaywallSheet: View {

    @EnvironmentObject private var pm: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var isRestoring  = false
    @State private var errorMessage: String? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── ヘッダービジュアル ──
                ZStack {
                    Color.blue.opacity(0.08)
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("プロにアップグレード")
                            .font(.title2.bold())

                        Text("ティア表を最大\(PurchaseManager.proLimit)個まで作成できます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 36)
                }

                // ── 特典リスト ──
                VStack(alignment: .leading, spacing: 20) {
                    featureRow(
                        icon: "square.grid.2x2.fill",
                        color: .blue,
                        text: "ティア表を最大\(PurchaseManager.proLimit)個まで保存"
                    )
                    featureRow(
                        icon: "photo.stack",
                        color: .orange,
                        text: "画像アイテムも制限なし"
                    )
                    featureRow(
                        icon: "arrow.clockwise",
                        color: .green,
                        text: "一度購入すれば永続利用・広告なし"
                    )
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // ── エラー表示 ──
                if let msg = errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }

                // ── ボタン群 ──
                VStack(spacing: 14) {

                    // 購入ボタン
                    Button {
                        Task { await doPurchase() }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text(purchaseButtonLabel)
                                    .bold()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isPurchasing || isRestoring || pm.isLoading)

                    // 復元ボタン
                    Button {
                        Task { await doRestore() }
                    } label: {
                        Group {
                            if isRestoring {
                                ProgressView()
                                    .frame(height: 20)
                            } else {
                                Text("以前の購入を復元する")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isPurchasing || isRestoring)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body.bold())
                    .foregroundColor(color)
            }
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Button Label

    private var purchaseButtonLabel: String {
        if pm.isLoading { return "読み込み中…" }
        if let product = pm.product {
            return "購入する（\(product.displayPrice)・買い切り）"
        }
        return "購入する"
    }

    // MARK: - Actions

    private func doPurchase() async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await pm.purchase()
            if pm.isPro { dismiss() }
        } catch PurchaseError.cancelled {
            // キャンセルはエラー表示しない
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    private func doRestore() async {
        isRestoring = true
        errorMessage = nil
        do {
            try await pm.restore()
            if pm.isPro {
                dismiss()
            } else {
                errorMessage = "復元できる購入が見つかりませんでした"
            }
        } catch {
            errorMessage = "復元に失敗しました。しばらく後にお試しください。"
        }
        isRestoring = false
    }
}

// MARK: - Preview

#Preview {
    PaywallSheet()
        .environmentObject(PurchaseManager.shared)
}
