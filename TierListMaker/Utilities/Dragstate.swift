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

/// 行ドラッグ状態：ラベル長押しドラッグによる行の並び替えを管理する。
///
/// draggingRowId : ドラッグ中の行 ID（nil = ドラッグ未発動）
/// targetRowId   : 現在ホバーしている移動先の行 ID
/// dragLocation  : グローバル座標でのドラッグ位置（ゴーストビューの表示に使用）
///
/// 更新頻度:
///   draggingRowId / targetRowId … 行ドラッグ開始・終了・行境界越え時のみ（低頻度）
///   dragLocation               … ドラッグ中の毎フレーム（高頻度）
/// ゴーストビューのみが dragLocation を @ObservedObject で購読するため、
/// TierRowView 本体の再描画は draggingRowId / targetRowId の変化時のみに抑えられる。
final class RowDragState: ObservableObject {
    @Published var draggingRowId: UUID? = nil
    @Published var targetRowId:   UUID? = nil
    @Published var dragLocation:  CGPoint = .zero
}
