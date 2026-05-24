import SwiftUI
import Combine

/// 位置状態：ドラッグ中に毎フレーム更新される高頻度の状態。
/// この変化で再描画が不要なViewには購読させない（let で受け取る）。
final class DragPositionState: ObservableObject {
    @Published var dragLocation: CGPoint = .zero
}

/// 操作状態：タップ・ドラッグ開始／終了時のみ更新される低頻度の状態。
final class DragInteractionState: ObservableObject {
    @Published var draggingItem: TierItem? = nil
    @Published var hoveredRowId: UUID? = nil
    @Published var selectedItem: TierItem? = nil
}
