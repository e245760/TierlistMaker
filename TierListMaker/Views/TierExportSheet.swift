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

    /// スクリーン幅を基準にキャンバスサイズ（pt）を返す
    func canvasSize(for width: CGFloat) -> CGSize {
        switch self {
        case .portrait:  return CGSize(width: width, height: width * 4 / 3)
        case .square:    return CGSize(width: width, height: width)
        case .landscape: return CGSize(width: width, height: width * 3 / 4)
        }
    }
}

// MARK: - TierExportSheet

/// 保存ボタンを押したときに表示するエクスポートシート。
///
/// 1. 比率選択（縦長 / 正方形 / 横長）
/// 2. TierListSnapshotView を ImageRenderer でキャンバス幅にレンダリング
/// 3. 選択した比率のキャンバスに透明背景で合成（PNG出力）
/// 4. 「写真アプリに保存」ボタンで PHPhotoLibrary に書き出す
struct TierExportSheet: View {

    let vm: TierListViewModel
    let title: String

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedRatio: ExportAspectRatio = .square
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering = true
    @State private var isSaving    = false
    @State private var savedOK     = false
    @State private var showPermissionAlert = false

    // MARK: - Body

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
        // 初回レンダリング
        .task { await renderImage() }
        // 比率変更時に再レンダリング
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

    // MARK: - レンダリング中プレースホルダー

    private var renderingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("プレビューを生成中…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - プレビューコンテンツ

    @ViewBuilder
    private func previewContent(image: UIImage) -> some View {
        VStack(spacing: 0) {

            // 画像プレビュー
            ScrollView {
                // 透明部分をわかりやすくするためチェッカー背景を敷く
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

                // ── 比率セレクター ──
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

                // ── 保存ボタン ──
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
                        Text(saveButtonLabel)
                            .bold()
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

    // MARK: - レンダリング

    /// 処理の流れ:
    ///   1. TierListSnapshotView をキャンバス幅でレンダリング
    ///   2. 選択した比率のキャンバスを透明で生成
    ///   3. スナップショットを高さ方向で収まるよう縮小、中央配置して合成
    @MainActor
    private func renderImage() async {
        isRendering = true
        savedOK     = false   // 比率が変わったら保存済みフラグをリセット

        let scale       = UIScreen.main.scale
        let screenWidth = UIScreen.main.bounds.width
        let canvasSize  = selectedRatio.canvasSize(for: screenWidth)

        // Step 1: スナップショットをキャンバス幅でレンダリング
        let snapshot = TierListSnapshotView(
            rows: vm.rows,
            title: title,
            defaultLabelSize: vm.defaultLabelSize,
            defaultLabelTextSize: vm.defaultLabelTextSize,
            defaultItemSize: vm.defaultItemSize,
            tierTheme: vm.tierTheme,
            canvasWidth: canvasSize.width
        )
        let snapshotRenderer = ImageRenderer(content: snapshot)
        snapshotRenderer.scale = scale
        guard let snapshotImage = snapshotRenderer.uiImage else {
            isRendering = false
            return
        }

        // Step 2: スナップショットがキャンバスより高い場合のみ縮小
        let snapshotSize = snapshotImage.size   // UIImage.size は pt 単位
        let fitScale: CGFloat = snapshotSize.height > canvasSize.height
            ? canvasSize.height / snapshotSize.height
            : 1.0

        let drawWidth  = snapshotSize.width  * fitScale
        let drawHeight = snapshotSize.height * fitScale
        let drawX      = (canvasSize.width  - drawWidth)  / 2
        let drawY      = (canvasSize.height - drawHeight) / 2

        // Step 3: 透明背景キャンバスに合成 → PNG として保持
        let format        = UIGraphicsImageRendererFormat()
        format.opaque     = false   // アルファチャンネルを有効化
        format.scale      = scale
        let uiRenderer    = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let composited    = uiRenderer.image { _ in
            snapshotImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }

        renderedImage = composited
        isRendering   = false
    }

    // MARK: - 写真ライブラリへの保存（PNG形式）

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

    /// PNG データとして保存することで透明チャンネルを保持する。
    /// PHAssetCreationRequest を使いフォーマットを明示指定。
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

// MARK: - チェッカーボード背景（透明部分の視覚的表示）
//
// プレビュー上で透明エリアを示す。
// TierExportSheet 専用の軽量実装（Canvas を使わずシンプルに）。

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
                            width:  tileSize,
                            height: tileSize
                        )),
                        with: .color(isLight ? Color(.systemGray5) : Color(.systemGray4))
                    )
                }
            }
        }
    }
}
