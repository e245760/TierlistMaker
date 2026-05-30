import SwiftUI

// MARK: - 環境キー：同期ロードモード
//
// ImageRenderer（TierListSnapshotView）はSwiftUIのライフサイクルを持たないため
// .task が実行されない。スナップショット用に同期ロードへ切り替えるための環境値。
// 通常のインタラクティブ表示では false（デフォルト）のまま使う。

private struct SyncImageLoadingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var syncImageLoading: Bool {
        get { self[SyncImageLoadingKey.self] }
        set { self[SyncImageLoadingKey.self] = newValue }
    }
}

// MARK: - TierItemView

struct TierItemView: View {
    let item: TierItem

    @Environment(\.tierTheme)          private var tierTheme
    @Environment(\.syncImageLoading)   private var syncImageLoading

    // 非同期ロード結果を保持するState
    // ForEach内でもTierItemのid安定性によりSwiftUIがビューを正しく同定するため
    // スクロール復帰時はキャッシュヒット（高速）になる
    @State private var loadedImage: UIImage? = nil

    // MARK: - Body

    var body: some View {
        Group {
            if item.imageFileName != nil {
                imageContent
            } else {
                textContent
            }
        }
        .frame(width: item.itemSize.width, height: item.itemSize.height)
        .background(backgroundColor)
        .clipShape(itemClipShape)
        // imageFileNameが変わったとき（将来の差し替え対応）も再ロードする
        .task(id: item.imageFileName) {
            // syncImageLoadingモードではbodyで同期ロードするのでtaskは何もしない
            guard !syncImageLoading else { return }
            await loadImageAsync()
        }
    }

    // MARK: - 画像表示

    @ViewBuilder
    private var imageContent: some View {
        let uiImage: UIImage? = syncImageLoading
            ? item.imageFileName.flatMap { ImageFileStore.shared.load(fileName: $0) }
            : loadedImage

        ZStack(alignment: .bottom) {
            if let uiImage {
                let (ox, oy, sc) = resolvedCrop(for: uiImage)
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(sc)
                    .offset(
                        x: ox * item.itemSize.width,
                        y: oy * item.itemSize.height
                    )
                    .scaleEffect(
                        x: item.isFlippedHorizontal ? -1 : 1,
                        y: item.isFlippedVertical   ? -1 : 1
                    )
                    .frame(width: item.itemSize.width, height: item.itemSize.height)
                    .clipped()
            } else {
                Color(hex: item.backgroundColorHex)
            }

            // ラベルが空でなければ下部に帯状テキストを表示
            if !item.label.isEmpty {
                Text(item.label)
                    .font(tierTheme.fontStyle.font(size: item.textSize.fontSize * 0.7))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(Color(hex: item.textColorHex))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(hex: item.backgroundColorHex).opacity(0.75)
                    )
            }
        }
        .frame(width: item.itemSize.width, height: item.itemSize.height)
    }

    // MARK: - テキスト表示（変更なし）

    @ViewBuilder
    private var textContent: some View {
        Text(item.label)
            .font(tierTheme.fontStyle.font(size: item.textSize.fontSize))
            .minimumScaleFactor(0.5)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundColor(Color(hex: item.textColorHex))
            .padding(4)
    }

    // MARK: - 非同期ロード

    private func loadImageAsync() async {
        guard let fileName = item.imageFileName else {
            loadedImage = nil
            return
        }

        // ① キャッシュヒット：ディスクI/Oなし、メインスレッドで即時完了
        if let cached = ImageFileStore.shared.cachedImage(fileName: fileName) {
            loadedImage = cached
            return
        }

        // ② キャッシュミス：バックグラウンドでディスクI/O
        //    load()はキャッシュへの書き込みも行うため、
        //    次回以降は①のパスで高速に返る
        let image = await Task.detached(priority: .userInitiated) {
            ImageFileStore.shared.load(fileName: fileName)
        }.value

        // ビューが消えてTaskがキャンセルされた場合は反映しない
        guard !Task.isCancelled else { return }
        loadedImage = image
    }

    // MARK: - 以下は変更なし

    private var backgroundColor: Color {
        // cropContain を常に true として扱うため透明背景は使わない
        return Color(hex: item.backgroundColorHex)
    }

    private func resolvedCrop(for uiImage: UIImage) -> (CGFloat, CGFloat, CGFloat) {
        // cropContain を常に true として扱う（制限なしモードは廃止）
        let clampedScale = max(1.0, item.cropScale)
        let (maxX, maxY) = maxAllowedOffset(for: uiImage, scale: clampedScale)
        return (
            item.cropOffsetX.clamped(to: -maxX...maxX),
            item.cropOffsetY.clamped(to: -maxY...maxY),
            clampedScale
        )
    }

    func maxAllowedOffset(for uiImage: UIImage, scale: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let fW = item.itemSize.width,  fH = item.itemSize.height
        let imgW = uiImage.size.width, imgH = uiImage.size.height
        guard imgH > 0, fW > 0, fH > 0 else { return (0, 0) }
        let imgAspect = imgW / imgH, frameAspect = fW / fH
        let fillW: CGFloat, fillH: CGFloat
        if imgAspect > frameAspect { fillH = fH; fillW = imgAspect * fH }
        else                       { fillW = fW; fillH = fW / imgAspect }
        return (
            x: max(0, (scale * fillW - fW) / 2.0 / fW),
            y: max(0, (scale * fillH - fH) / 2.0 / fH)
        )
    }

    private var itemClipShape: AnyShape {
        item.itemSize == .circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
