import SwiftUI

struct TierItemView: View {
    let item: TierItem

    var body: some View {
        Group {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
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
            } else {
                Text(item.label)
                    .font(.system(size: item.textSize.fontSize, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: item.textColorHex))
                    .padding(4)
            }
        }
        .frame(width: item.itemSize.width, height: item.itemSize.height)
        .background(backgroundColor)
        .clipShape(itemClipShape)
    }

    // MARK: - 背景色

    /// cropContain が OFF かつ cropTransparentBg が ON のとき透明にする
    private var backgroundColor: Color {
        if !item.cropContain && item.cropTransparentBg {
            return .clear
        }
        return Color(hex: item.backgroundColorHex)
    }

    // MARK: - クロップ値の解決

    /// containMode ON 時はスケール・オフセットを「グレーが出ない範囲」に丸めて返す。
    /// OFF 時はそのまま返す。
    private func resolvedCrop(for uiImage: UIImage) -> (offsetX: CGFloat, offsetY: CGFloat, scale: CGFloat) {
        if item.cropContain {
            let clampedScale = max(1.0, item.cropScale)
            let (maxX, maxY) = maxAllowedOffset(for: uiImage, scale: clampedScale)
            let cx = item.cropOffsetX.clamped(to: -maxX...maxX)
            let cy = item.cropOffsetY.clamped(to: -maxY...maxY)
            return (cx, cy, clampedScale)
        } else {
            return (item.cropOffsetX, item.cropOffsetY, item.cropScale)
        }
    }

    /// 画像のアスペクト比とスケールから、グレーが出ない最大正規化オフセットを計算する。
    ///
    /// scaledToFill 後の画像サイズを基準に、
    /// scaleEffect(s) を適用した場合のはみ出し量から算出する。
    func maxAllowedOffset(for uiImage: UIImage, scale: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let fW = item.itemSize.width
        let fH = item.itemSize.height
        let imgW = uiImage.size.width
        let imgH = uiImage.size.height
        guard imgH > 0, fW > 0, fH > 0 else { return (0, 0) }

        // scaledToFill 後のサイズ（フレームを完全に覆う最小サイズ）
        let imgAspect = imgW / imgH
        let frameAspect = fW / fH
        let fillW: CGFloat
        let fillH: CGFloat
        if imgAspect > frameAspect {
            // 横長画像 → 高さに合わせて幅が余る
            fillH = fH
            fillW = imgAspect * fH
        } else {
            // 縦長画像 → 幅に合わせて高さが余る
            fillW = fW
            fillH = fW / imgAspect
        }

        // scaleEffect(s) 後のサイズ
        let scaledW = scale * fillW
        let scaledH = scale * fillH

        // 各方向のはみ出し量（ピクセル）→ 正規化
        let maxPxX = (scaledW - fW) / 2.0
        let maxPxY = (scaledH - fH) / 2.0
        return (
            x: max(0, maxPxX / fW),
            y: max(0, maxPxY / fH)
        )
    }
    
    // MARK: - クリップ形状

    private var itemClipShape: AnyShape {
        item.itemSize == .circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - clamp helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
