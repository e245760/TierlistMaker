import SwiftUI

struct TierItemView: View {
    let item: TierItem

    var body: some View {
        Group {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    // クロップ：まずスケール変更、次にオフセット（正規化値 × フレームサイズ）
                    .scaleEffect(item.cropScale)
                    .offset(
                        x: item.cropOffsetX * item.itemSize.width,
                        y: item.cropOffsetY * item.itemSize.height
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
        .background(Color(hex: item.backgroundColorHex))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
