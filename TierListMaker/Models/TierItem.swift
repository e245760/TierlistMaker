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
    case xSmall = "xSmall"
    case small  = "small"
    case medium = "medium"
    case large  = "large"   // デフォルト
    case xLarge = "xLarge"

    var fontSize: CGFloat {
        switch self {
        case .xSmall: return 9
        case .small:  return 11
        case .medium: return 13
        case .large:  return 15
        case .xLarge: return 18
        }
    }

    var label: String {
        switch self {
        case .xSmall: return "極小"
        case .small:  return "小"
        case .medium: return "中"
        case .large:  return "大"
        case .xLarge: return "極大"
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
    // 画像用
    var isFlippedHorizontal: Bool
    var isFlippedVertical: Bool

    init(
        id: UUID = UUID(),
        label: String,
        imageData: Data? = nil,
        itemSize: ItemSize = .square,
        textSize: ItemTextSize = .large,
        textColorHex: String = "#000000",
        backgroundColorHex: String = "#AAAAAA",
        isFlippedHorizontal: Bool = false,
        isFlippedVertical: Bool = false
    ) {
        self.id = id
        self.label = label
        self.imageData = imageData
        self.itemSize = itemSize
        self.textSize = textSize
        self.textColorHex = textColorHex
        self.backgroundColorHex = backgroundColorHex
        self.isFlippedHorizontal = isFlippedHorizontal
        self.isFlippedVertical = isFlippedVertical
    }
}
