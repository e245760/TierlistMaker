import SwiftUI
import Combine

/// 位置状態：ドラッグ中に毎フレーム更新される高頻度の状態。
final class DragPositionState: ObservableObject {
    @Published var dragLocation: CGPoint = .zero
}

/// ホバー状態：ドラッグ中に行をまたぐたびに更新される中頻度の状態。
/// DragInteractionState から分離することで、selectedItem / draggingItem の変化が
/// TierRowView の再描画を引き起こさなくなる。
final class DragHoverState: ObservableObject {
    @Published var hoveredRowId: UUID? = nil
}

/// 操作状態：タップ・ドラッグ開始／終了時のみ更新される低頻度の状態。
final class DragInteractionState: ObservableObject {
    @Published var draggingItem: TierItem? = nil
    @Published var selectedItem: TierItem? = nil
    // hoveredRowId は DragHoverState に移動
}
