import Foundation
import SwiftUI

enum LabelSize: String, CaseIterable, Codable {
    case narrow = "narrow"
    case square = "square"
    case wide   = "wide"

    var width: CGFloat {
        switch self {
        case .narrow: return 50
        case .square: return 70
        case .wide:   return 100
        }
    }

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

enum LabelTextSize: String, CaseIterable, Codable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    var fontSize: CGFloat {
        switch self {
        case .small:  return 13
        case .medium: return 17
        case .large:  return 22
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

struct TierRow: Identifiable, Codable, Equatable {
    let id: UUID
    var tierName: String
    var color: String
    var textColorHex: String
    var items: [TierItem]

    static let maxLabelLength = 5

    init(
        id: UUID = UUID(),
        tierName: String,
        color: String,
        textColorHex: String = "#000000",
        items: [TierItem] = []
    ) {
        self.id = id
        self.tierName = tierName
        self.color = color
        self.textColorHex = textColorHex
        self.items = items
    }
}
