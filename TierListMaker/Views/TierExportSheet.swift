import SwiftUI
import Photos

/// 保存ボタンを押したときに表示するエクスポートシート。
///
/// 1. 表示直後に TierListSnapshotView を ImageRenderer で画像化
/// 2. プレビューを ScrollView に表示
/// 3. 「写真アプリに保存」ボタンで PHPhotoLibrary に書き出す
struct TierExportSheet: View {

    let vm: TierListViewModel
    let title: String

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

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
        // シート表示直後にレンダリング開始
        .task { await renderImage() }
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(16)
            }

            Divider()

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
                    Text(saveButtonLabel)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(savedOK ? Color.green : Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .animation(.spring(), value: savedOK)
            }
            .disabled(isSaving || savedOK)
        }
    }

    private var saveButtonLabel: String {
        if isSaving { return "保存中…" }
        if savedOK  { return "保存しました" }
        return "写真アプリに保存"
    }

    // MARK: - レンダリング

    /// ImageRenderer はメインスレッドで実行する必要がある
    @MainActor
    private func renderImage() async {
        let snapshot = TierListSnapshotView(
            rows: vm.rows,
            title: title,
            defaultLabelSize: vm.defaultLabelSize,
            defaultLabelTextSize: vm.defaultLabelTextSize,
            defaultItemSize: vm.defaultItemSize,
            tierTheme: vm.tierTheme
        )
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = UIScreen.main.scale   // Retina 解像度で出力
        renderedImage = renderer.uiImage
        isRendering   = false
    }

    // MARK: - 写真ライブラリへの保存

    @MainActor
    private func requestAndSave() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            await saveImage()
        case .notDetermined:
            // 初回：権限ダイアログを表示して結果を待つ
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
            // denied / restricted
            showPermissionAlert = true
        }
    }

    private func saveImage() async {
        guard let image = renderedImage else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            withAnimation(.spring()) { savedOK = true }
        } catch {
            print("[TierExportSheet] 写真保存エラー: \(error)")
        }
    }
}
