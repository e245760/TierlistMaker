//
//  TierItem.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/18.
//

import Foundation
import UIKit

struct TierItem: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var imageData: Data?

    init(id: UUID = UUID(), label: String, imageData: Data? = nil) {
        self.id = id
        self.label = label
        self.imageData = imageData
    }
}
