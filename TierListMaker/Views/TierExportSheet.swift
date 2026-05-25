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
///
/// [B] 自然高さ > キャンバス高さ（オーバーフロー）
///     「仮想幅」を二分探索で求める。
///     virtualWidth × s = canvasWidth になる virtualWidth を探し、
///     その幅でレンダリング → スケール s で縮小 → キャンバスにぴったり合成。
///     透明余白なし。アイテムは s 倍（若干縮小）。
///
/// 出力は常に PNG（透明チャンネル保持）。
struct TierExportSheet: View {

    let vm: TierListViewModel
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var selectedRatio: ExportAspectRatio = .square
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering = true
    @State private var isSaving    = false
    @State private var savedOK     = false
    @State private var showPermissionAlert = false

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
        .onChange(of: selectedRatio) { _ in
            Task { await renderImage() }
        }
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
                // 比率セレクター
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

                // 保存ボタン
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

    // MARK: - Render

    @MainActor
    private func renderImage() async {
        isRendering = true
        savedOK     = false

        let scale       = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width
        let canvasSize  = selectedRatio.canvasSize(for: screenWidth)

        // ── Phase 1: プローブレンダリングで正確な自然高さを計測 ──
        guard let probeImage = render(canvasWidth: canvasSize.width,
                                      targetHeight: nil,
                                      scale: scale) else {
            isRendering = false
            return
        }
        let naturalHeight = probeImage.size.height

        if naturalHeight <= canvasSize.height {
            // ── ケース A: 行引き伸ばし ──
            renderedImage = render(canvasWidth: canvasSize.width,
                                   targetHeight: canvasSize.height,
                                   scale: scale)

        } else {
            // ── ケース B: 仮想幅グリッド再計算 ──
            //
            // 目標: virtualWidth × s = canvasWidth
            //       s = canvasHeight / naturalHeight(virtualWidth)
            //
            // virtualWidth を二分探索で求め、その幅でレンダリングして
            // スケール s で縮小すると幅・高さともキャンバスにぴったり収まる。

            let virtualWidth = findOptimalVirtualWidth(canvasSize: canvasSize)

            guard let expandedImage = render(canvasWidth: virtualWidth,
                                              targetHeight: nil,
                                              scale: scale) else {
                isRendering = false
                return
            }

            // 実際の描画高さを使ってスケールを確定（近似誤差を吸収）
            let s     = canvasSize.height / expandedImage.size.height
            let drawW = expandedImage.size.width  * s
            let drawH = expandedImage.size.height * s
            // 二分探索の精度により drawX, drawY は ≈ 0（最大でも数 pt 以内）
            let drawX = (canvasSize.width  - drawW) / 2
            let drawY = (canvasSize.height - drawH) / 2

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

    /// TierListSnapshotView を指定パラメータでレンダリングして UIImage を返す。
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
            targetHeight: targetHeight
        )
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = scale
        return renderer.uiImage
    }

    // MARK: - Virtual Width Binary Search

    /// TierListSnapshotView の高さ計算を模倣し、指定幅での自然な高さを返す。
    ///
    /// ヘッダー高さ（36pt）は近似値だが、最終的に実際の描画高さで補正するため問題ない。
    /// TierListSnapshotView の以下のロジックを再現する:
    ///   - itemsPerRow = floor(itemAreaWidth / (itemWidth + 4))
    ///   - rowHeight   = max(itemH + 8, chunkCount × (itemH + 4) + 8)
    ///   - separators  = rows.count × 0.5pt（各行の下）
    private func computeNaturalHeight(virtualWidth: CGFloat) -> CGFloat {
        let itemH       = vm.defaultItemSize.height
        let itemW       = vm.defaultItemSize.width
        let labelW      = vm.defaultLabelSize.width
        let itemAreaW   = virtualWidth - labelW
        let perRow      = max(1, Int(itemAreaW / (itemW + 4)))
        let headerH: CGFloat  = 36          // subheadline + padding×2 + divider
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

    /// `virtualWidth × s = canvasWidth`（s = canvasHeight / naturalHeight(virtualWidth)）
    /// を満たす最小の virtualWidth を二分探索で求める。
    ///
    /// アルゴリズムの根拠:
    ///   f(vw) = vw × (canvasHeight / naturalHeight(vw)) は単調非減少。
    ///   ・行内区間: naturalHeight 一定、vw 増加 → f 増加
    ///   ・行数が変わる境界: naturalHeight が段階的に減少 → s が増加 → f がジャンプ増加
    ///   よって二分探索が有効。
    ///
    /// 収束後の virtualWidth でレンダリングし、実際の描画高さでスケールを再計算
    /// することで、近似ヘッダー高さの誤差（±2pt程度）を吸収する。
    private func findOptimalVirtualWidth(canvasSize: CGSize) -> CGFloat {
        // 上限：最多アイテム行が1行に収まる幅
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
            // mid × s がキャンバス幅を下回るなら → まだ幅が足りない
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
