import Foundation
import UIKit

enum ItemSize: String, CaseIterable, Codable {
    case narrow = "narrow"
    case square = "square"
    case wide   = "wide"

    var width: CGFloat {
        switch self {
        case .narrow: return 50
        case .square: return 65
        case .wide:   return 100
        }
    }

    var height: CGFloat { 65 }

    var label: String {
        switch self {
        case .narrow: return "縦長"
        case .square: return "正方形"
        case .wide:   return "横長"
        }
    }

    var icon: String {
        switch self {
        case .narrow: return "rectangle.portrait"
        case .square: return "square"
        case .wide:   return "rectangle"
        }
    }
}

enum ItemTextSize: String, CaseIterable, Codable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    var fontSize: CGFloat {
        switch self {
        case .small:  return 11
        case .medium: return 13
        case .large:  return 15
        }
    }

    var label: String {
        switch self {
        case .small:  return "小"
        case .medium: return "中"
        case .large:  return "大"
        }
    }
}

struct TierItem: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var imageData: Data?
    var itemSize: ItemSize
    // テキスト用
    var textSize: ItemTextSize
    var textColorHex: String
    var backgroundColorHex: String
    // 画像用：反転
    var isFlippedHorizontal: Bool
    var isFlippedVertical: Bool
    // 画像用：クロップ（正規化値。itemSizeの幅・高さに対する比率）
    var cropOffsetX: CGFloat    // -1.0 〜 1.0、0が中央
    var cropOffsetY: CGFloat    // -1.0 〜 1.0、0が中央
    var cropScale: CGFloat      // 0.5 〜 5.0、1.0が等倍
    // 画像用：はみ出し制御
    /// true のとき、スケール・オフセットをグレー背景が見えない範囲に制限する
    var cropContain: Bool
    /// true のとき（cropContain = false 時のみ有効）、グレー背景の代わりに透明を使う
    var cropTransparentBg: Bool

    init(
        id: UUID = UUID(),
        label: String,
        imageData: Data? = nil,
        itemSize: ItemSize = .square,
        textSize: ItemTextSize = .large,
        textColorHex: String = "#000000",
        backgroundColorHex: String = "#AAAAAA",
        isFlippedHorizontal: Bool = false,
        isFlippedVertical: Bool = false,
        cropOffsetX: CGFloat = 0,
        cropOffsetY: CGFloat = 0,
        cropScale: CGFloat = 1.0,
        cropContain: Bool = true,
        cropTransparentBg: Bool = false
    ) {
        self.id                  = id
        self.label               = label
        self.imageData           = imageData
        self.itemSize            = itemSize
        self.textSize            = textSize
        self.textColorHex        = textColorHex
        self.backgroundColorHex  = backgroundColorHex
        self.isFlippedHorizontal = isFlippedHorizontal
        self.isFlippedVertical   = isFlippedVertical
        self.cropOffsetX         = cropOffsetX
        self.cropOffsetY         = cropOffsetY
        self.cropScale           = cropScale
        self.cropContain         = cropContain
        self.cropTransparentBg   = cropTransparentBg
    }

    // MARK: - Codable（後方互換：旧キーが無い場合はデフォルト値）

    enum CodingKeys: String, CodingKey {
        case id, label, imageData, itemSize, textSize
        case textColorHex, backgroundColorHex
        case isFlippedHorizontal, isFlippedVertical
        case cropOffsetX, cropOffsetY, cropScale
        case cropContain, cropTransparentBg
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(UUID.self,          forKey: .id)
        label               = try c.decode(String.self,        forKey: .label)
        imageData           = try c.decodeIfPresent(Data.self, forKey: .imageData)
        itemSize            = try c.decode(ItemSize.self,      forKey: .itemSize)
        textSize            = try c.decode(ItemTextSize.self,  forKey: .textSize)
        textColorHex        = try c.decode(String.self,        forKey: .textColorHex)
        backgroundColorHex  = try c.decode(String.self,        forKey: .backgroundColorHex)
        isFlippedHorizontal = try c.decode(Bool.self,          forKey: .isFlippedHorizontal)
        isFlippedVertical   = try c.decode(Bool.self,          forKey: .isFlippedVertical)
        cropOffsetX         = try c.decodeIfPresent(CGFloat.self, forKey: .cropOffsetX) ?? 0
        cropOffsetY         = try c.decodeIfPresent(CGFloat.self, forKey: .cropOffsetY) ?? 0
        cropScale           = try c.decodeIfPresent(CGFloat.self, forKey: .cropScale)   ?? 1.0
        cropContain         = try c.decodeIfPresent(Bool.self,    forKey: .cropContain) ?? true
        cropTransparentBg   = try c.decodeIfPresent(Bool.self,    forKey: .cropTransparentBg) ?? false
    }
}
