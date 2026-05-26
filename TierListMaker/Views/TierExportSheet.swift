import SwiftUI
import Photos

// MARK: - ExportAspectRatio

enum ExportAspectRatio: String, CaseIterable {
    case portrait  = "portrait"
    case square    = "square"
    case landscape = "landscape"

    var label: String {
        switch self {
        case .portrait:  return "縦長"
        case .square:    return "正方形"
        case .landscape: return "横長"
        }
    }

    var icon: String {
        switch self {
        case .portrait:  return "rectangle.portrait"
        case .square:    return "square"
        case .landscape: return "rectangle"
        }
    }

    func canvasSize(for width: CGFloat) -> CGSize {
        switch self {
        case .portrait:  return CGSize(width: width, height: width * 4 / 3)
        case .square:    return CGSize(width: width, height: width)
        case .landscape: return CGSize(width: width, height: width * 3 / 4)
        }
    }
}

// MARK: - TierExportSheet

/// ── レンダリング戦略 ──
///
/// Phase 1: canvasWidth でプローブレンダリングして正確な自然高さを計測
///
/// [A] 自然高さ ≤ キャンバス高さ
///     targetHeight を渡して行を引き伸ばしキャンバスを埋める（透明なし）
///     ※ 高さ配分は TierListSnapshotView 内の反復アルゴリズムで行う
///
/// [B] 自然高さ > キャンバス高さ（オーバーフロー）
///     「仮想幅」を二分探索で求め、その幅でレンダリングしてスケールダウン。
///     スケール係数は min(幅方向, 高さ方向) で両方向の溢れを防ぐ。
///
/// 出力は常に PNG（透明チャンネル保持）。
struct TierExportSheet: View {

    let vm: TierListViewModel
    let title: String

    @Environment(\.dismiss) private var dismiss

    // Pro判定（ウォーターマークトグルの表示制御に使用）
    @ObservedObject private var pm = PurchaseManager.shared

    @State private var selectedRatio: ExportAspectRatio = .square
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering = true
    @State private var isSaving    = false
    @State private var savedOK     = false
    @State private var showPermissionAlert = false
    /// Pro購入済みユーザーのみ切り替え可能。無料ユーザーは常に true（表示）。
    @State private var showWatermark: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if isRendering {
                    renderingPlaceholder
                } else if let image = renderedImage {
                    previewContent(image: image)
                } else {
                    Text("プレビューの生成に失敗しました")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .task { await renderImage() }
        .onChange(of: selectedRatio)   { _ in Task { await renderImage() } }
        .onChange(of: showWatermark)   { _ in Task { await renderImage() } }
        .alert("写真へのアクセスを許可してください", isPresented: $showPermissionAlert) {
            Button("設定を開く") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("設定 › プライバシーとセキュリティ › 写真 からアクセスを許可してください。")
        }
    }

    // MARK: - Rendering Placeholder

    private var renderingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("プレビューを生成中…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Preview Content

    @ViewBuilder
    private func previewContent(image: UIImage) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                ZStack {
                    CheckerboardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .padding(16)
            }

            Divider()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    ForEach(ExportAspectRatio.allCases, id: \.self) { ratio in
                        let isSelected = selectedRatio == ratio
                        Button {
                            withAnimation(.spring()) { selectedRatio = ratio }
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: ratio.icon)
                                    .font(.title3)
                                    .foregroundColor(isSelected ? .white : .primary)
                                Text(ratio.label)
                                    .font(.caption.bold())
                                    .foregroundColor(isSelected ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Color.blue : Color(.systemGray5))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRendering)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // ── ウォーターマーク切り替え（Pro限定） ──
                watermarkToggleRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                Button {
                    Task { await requestAndSave() }
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: savedOK
                                  ? "checkmark.circle.fill"
                                  : "square.and.arrow.down.fill")
                        }
                        Text(saveButtonLabel).bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(savedOK ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .animation(.spring(), value: savedOK)
                }
                .disabled(isSaving || savedOK || isRendering)
            }
        }
    }

    private var saveButtonLabel: String {
        if isSaving { return "保存中…" }
        if savedOK  { return "保存しました" }
        return "写真アプリに保存（PNG）"
    }

    // MARK: - ウォーターマーク切り替え行

    /// Pro購入済み: トグルスイッチで ON/OFF を切り替え可能。
    /// 非Pro         : ロックバッジを表示し、タップで何もしない（常に ON）。
    @State private var showPaywall = false

    @ViewBuilder
    private var watermarkToggleRow: some View {
        HStack(spacing: 12) {
            // アイコン＋ラベル
            Image(systemName: showWatermark ? "star.fill" : "star.slash")
                .font(.subheadline)
                .foregroundColor(showWatermark ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("ロゴ")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(pm.isPro
                     ? (showWatermark ? "画像に表示されます" : "画像に表示されません")
                     : "プロにアップグレードすると非表示にできます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if pm.isPro {
                Toggle("", isOn: $showWatermark)
                    .labelsHidden()
                    .tint(.blue)
            } else {
                // 非Pro: タップでペイウォールを開く
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption.bold())
                        Text("Pro")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(pm: pm)
        }
    }

    // MARK: - Render

    @MainActor
    private func renderImage() async {
        isRendering = true
        savedOK     = false

        let scale       = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width
        let canvasSize  = selectedRatio.canvasSize(for: screenWidth)

        // Phase 1: 正確な自然高さを計測
        guard let probeImage = render(canvasWidth: canvasSize.width,
                                      targetHeight: nil,
                                      scale: scale) else {
            isRendering = false
            return
        }
        let naturalHeight = probeImage.size.height

        if naturalHeight <= canvasSize.height {
            // ── ケース A: 行引き伸ばし ──
            // TierListSnapshotView 内の反復アルゴリズムが各行の高さを正しく配分する
            renderedImage = render(canvasWidth: canvasSize.width,
                                   targetHeight: canvasSize.height,
                                   scale: scale)

        } else {
            // ── ケース B: 仮想幅グリッド再計算 ──
            let virtualWidth = findOptimalVirtualWidth(canvasSize: canvasSize)

            guard let expandedImage = render(canvasWidth: virtualWidth,
                                              targetHeight: nil,
                                              scale: scale) else {
                isRendering = false
                return
            }

            // min(幅スケール, 高さスケール) で両方向の溢れを防ぐ
            // → drawX, drawY が必ず ≥ 0 になりクリッピングなし
            let sW    = canvasSize.width  / expandedImage.size.width
            let sH    = canvasSize.height / expandedImage.size.height
            let s     = min(sW, sH)
            let drawW = expandedImage.size.width  * s
            let drawH = expandedImage.size.height * s
            let drawX = (canvasSize.width  - drawW) / 2   // ≥ 0 保証
            let drawY = (canvasSize.height - drawH) / 2   // ≥ 0 保証

            let format    = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale  = scale
            let uiRenderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
            renderedImage  = uiRenderer.image { _ in
                expandedImage.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
            }
        }

        isRendering = false
    }

    @MainActor
    private func render(canvasWidth: CGFloat,
                        targetHeight: CGFloat?,
                        scale: CGFloat) -> UIImage? {
        let snapshot = TierListSnapshotView(
            rows: vm.rows,
            title: title,
            defaultLabelSize: vm.defaultLabelSize,
            defaultLabelTextSize: vm.defaultLabelTextSize,
            defaultItemSize: vm.defaultItemSize,
            tierTheme: vm.tierTheme,
            canvasWidth: canvasWidth,
            targetHeight: targetHeight,
            showWatermark: showWatermark
        )
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = scale
        return renderer.uiImage
    }

    // MARK: - Virtual Width Binary Search

    /// TierListSnapshotView の高さ計算を模倣し、指定幅での自然な高さを返す（近似）。
    private func computeNaturalHeight(virtualWidth: CGFloat) -> CGFloat {
        let itemH      = vm.defaultItemSize.height
        let itemW      = vm.defaultItemSize.width
        let labelW     = vm.defaultLabelSize.width
        let itemAreaW  = virtualWidth - labelW
        let perRow     = max(1, Int(itemAreaW / (itemW + 4)))
        let headerH: CGFloat   = 36
        let separators: CGFloat = CGFloat(vm.rows.count) * 0.5

        let rowsH = vm.rows.reduce(CGFloat(0)) { acc, row in
            let count  = row.items.count
            let chunks = count == 0 ? 0 : Int(ceil(Double(count) / Double(perRow)))
            let minH   = itemH + 8
            let rowH   = chunks == 0 ? minH : max(minH, CGFloat(chunks) * (itemH + 4) + 8)
            return acc + rowH
        }
        return headerH + rowsH + separators
    }

    /// `virtualWidth × s = canvasWidth`（s = canvasHeight / naturalHeight(vw)）を
    /// 満たす最小の virtualWidth を二分探索で求める。
    ///
    /// f(vw) = vw × (canvasHeight / naturalHeight(vw)) は単調非減少のため二分探索が有効。
    private func findOptimalVirtualWidth(canvasSize: CGSize) -> CGFloat {
        let maxItems = vm.rows.map { $0.items.count }.max() ?? 1
        let hiBase   = vm.defaultLabelSize.width
                     + CGFloat(max(maxItems, 1)) * (vm.defaultItemSize.width + 4)
                     + 8
        var lo: CGFloat = canvasSize.width
        var hi: CGFloat = max(hiBase, canvasSize.width * 3)

        for _ in 0..<64 {
            guard hi - lo > 0.25 else { break }
            let mid      = (lo + hi) / 2
            let naturalH = computeNaturalHeight(virtualWidth: mid)
            let s        = canvasSize.height / naturalH
            if mid * s < canvasSize.width - 0.5 {
                lo = mid
            } else {
                hi = mid
            }
        }
        return hi
    }

    // MARK: - Save

    @MainActor
    private func requestAndSave() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            await saveImage()
        case .notDetermined:
            let granted = await withCheckedContinuation { cont in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) {
                    cont.resume(returning: $0)
                }
            }
            if granted == .authorized || granted == .limited {
                await saveImage()
            } else {
                showPermissionAlert = true
            }
        default:
            showPermissionAlert = true
        }
    }

    private func saveImage() async {
        guard let image   = renderedImage,
              let pngData = image.pngData() else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: pngData, options: nil)
            }
            withAnimation(.spring()) { savedOK = true }
        } catch {
            print("[TierExportSheet] 写真保存エラー: \(error)")
        }
    }
}

// MARK: - Checkerboard Background

private struct CheckerboardBackground: View {
    private let tileSize: CGFloat = 10

    var body: some View {
        Canvas { ctx, size in
            let cols = Int(ceil(size.width  / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    ctx.fill(
                        Path(CGRect(
                            x: CGFloat(col) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize, height: tileSize
                        )),
                        with: .color(isLight ? Color(.systemGray5) : Color(.systemGray4))
                    )
                }
            }
        }
    }
}
