//
//  TierItemView.swift
//  TierListMaker
//
//  Created by Tome Kanya   on 2026/05/18.
//

import SwiftUI

struct TierItemView: View {
    let item: TierItem

    var body: some View {
        Group {
            if let data = item.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(item.label)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
        }
        .frame(width: 60, height: 60)
        .background(Color(.systemGray4))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
