import StoreKit
import SwiftUI
import Combine

// MARK: - PurchaseManager
//
// StoreKit 2 を使ってアプリ内課金（買い切り）を管理する。
// singleton（.shared）として使い、HomeView / LibraryView / PaywallSheet で共有する。
//
// ── 定数 ──
//   freeLimit : 無料で作れるティア表の上限（10個）
//   proLimit  : Pro購入後の上限（50個）
//   productId : App Store Connect に登録するプロダクトID（必要に応じて変更）

@MainActor
final class PurchaseManager: ObservableObject {

    static let shared = PurchaseManager()

    // MARK: - 定数

    static let freeLimit = 10
    static let proLimit  = 50

    /// App Store Connect で設定するプロダクトID
    let productId = "com.app.tierlist.pro"

    // MARK: - Published

    @Published private(set) var isPro: Bool = false
    @Published private(set) var product: Product? = nil
    @Published private(set) var isLoading: Bool = false

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        transactionListenerTask = listenForTransactions()
        Task { await load() }
    }

    deinit { transactionListenerTask?.cancel() }

    // MARK: - Computed

    /// 現在の上限（Pro: 50 / Free: 5）
    var limit: Int { isPro ? Self.proLimit : Self.freeLimit }

    /// 新規作成できるかどうか
    func canCreate(currentCount: Int) -> Bool {
        currentCount < limit
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: [productId])
            product = products.first
        } catch {
            print("[PurchaseManager] プロダクト取得エラー: \(error)")
        }

        await refreshPurchaseStatus()
    }

    // MARK: - Purchase

    func purchase() async throws {
        guard let product else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshPurchaseStatus()
            await transaction.finish()
        case .pending:
            throw PurchaseError.pending
        case .userCancelled:
            throw PurchaseError.cancelled
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restore() async throws {
        try await AppStore.sync()
        await refreshPurchaseStatus()
    }

    // MARK: - Private

    private func refreshPurchaseStatus() async {
        var hasPurchase = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productId,
               transaction.revocationDate == nil {
                hasPurchase = true
                break
            }
        }
        isPro = hasPurchase
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            // VerificationError の説明文を関連値として保持する。
            // 握り潰さずに渡すことでデバッグ・ログ解析が容易になる。
            throw PurchaseError.failedVerification(reason: error.localizedDescription)
        case .verified(let value):
            return value
        }
    }

    /// アプリ起動中に外部（他デバイス等）からトランザクションが来た場合を処理する
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if case .verified(let transaction) = result {
                    await self.refreshPurchaseStatus()
                    await transaction.finish()
                }
            }
        }
    }
}

// MARK: - PurchaseError

enum PurchaseError: LocalizedError {
    case productNotFound
    case failedVerification(reason: String)
    case pending
    case cancelled

    var errorDescription: String? {
        switch self {
        case .productNotFound:              return "プロダクト情報を取得できませんでした"
        case .failedVerification(let reason): return "購入の検証に失敗しました（\(reason)）"
        case .pending:                      return "購入が保留中です。承認後に反映されます"
        case .cancelled:                    return nil   // キャンセルはエラー表示不要
        }
    }
}
