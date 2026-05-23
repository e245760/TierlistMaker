import SwiftUI

/// 画像アイテムの切り取り範囲・拡大縮小を編集するビュー。
/// ImageItemEditSheet の NavigationStack 内に NavigationLink でプッシュして使う。
struct ImageCropEditView: View {

    // MARK: - Bindings（ImageItemEditSheet の @State と接続）

    @Binding var offsetX: CGFloat   // 正規化：-1.0 〜 1.0（0が中央）
    @Binding var offsetY: CGFloat   // 正規化：-1.0 〜 1.0（0が中央）
    @Binding var scale: CGFloat     // 0.5 〜 5.0（1.0が等倍）

    let imageData: Data?
    let itemSize: ItemSize

    // MARK: - Gesture transient state（ジェスチャー中のみ有効な差分値）

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    // MARK: - プレビューサイズ計算

    /// アイテムを画面内で見やすく表示するための倍率
    private var displayScale: CGFloat {
        let maxSide: CGFloat = 270
        return maxSide / max(itemSize.width, itemSize.height)
    }
    private var previewW: CGFloat { itemSize.width  * displayScale }
    private var previewH: CGFloat { itemSize.height * displayScale }

    // MARK: - ライブ値（ジェスチャー中の差分を加算）

    private var liveScale: CGFloat {
        (scale * pinchDelta).clamped(to: 0.5...5.0)
    }
    private var liveOffsetX: CGFloat {
        (offsetX + dragDelta.width  / previewW).clamped(to: -1.0...1.0)
    }
    private var liveOffsetY: CGFloat {
        (offsetY + dragDelta.height / previewH).clamped(to: -1.0...1.0)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offsetX = (offsetX + value.translation.width  / previewW).clamped(to: -1.0...1.0)
                offsetY = (offsetY + value.translation.height / previewH).clamped(to: -1.0...1.0)
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale = (scale * value).clamped(to: 0.5...5.0)
            }
    }

    // MARK: - クロップ設定済みフラグ

    private var hasCustomCrop: Bool {
        offsetX != 0 || offsetY != 0 || scale != 1.0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── プレビューエリア ──
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 10) {
                    Text("ドラッグで移動・ピンチで拡大縮小")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    previewImage
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.blue.opacity(0.4), lineWidth: 1.5)
                        )

                    Text("スライダーでも細かく調整できます")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 20)
            }
            .frame(height: previewH + 80)

            // ── スライダー＋リセット ──
            Form {

                // リセット
                Section {
                    Button {
                        withAnimation(.spring()) {
                            offsetX = 0
                            offsetY = 0
                            scale   = 1.0
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("デフォルトに戻す")
                        }
                        .foregroundColor(hasCustomCrop ? .red : .secondary)
                    }
                    .disabled(!hasCustomCrop)
                }

                // 水平位置
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("水平位置", systemImage: "arrow.left.and.right")
                                .font(.subheadline)
                            Spacer()
                            Text(offsetXLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 18)
                            Slider(value: $offsetX, in: -1.0...1.0)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 18)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 垂直位置
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("垂直位置", systemImage: "arrow.up.and.down")
                                .font(.subheadline)
                            Spacer()
                            Text(offsetYLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 18)
                            Slider(value: $offsetY, in: -1.0...1.0)
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 18)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 拡大縮小
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("拡大縮小", systemImage: "magnifyingglass")
                                .font(.subheadline)
                            Spacer()
                            Text(scaleLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "minus.magnifyingglass")
                                .foregroundColor(.secondary)
                                .frame(width: 18)
                            Slider(value: $scale, in: 0.5...5.0)
                            Image(systemName: "plus.magnifyingglass")
                                .foregroundColor(.secondary)
                                .frame(width: 18)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("切り取り・拡大縮小")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - プレビュー画像

    @ViewBuilder
    private var previewImage: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .scaleEffect(liveScale)
                .offset(
                    x: liveOffsetX * previewW,
                    y: liveOffsetY * previewH
                )
                .frame(width: previewW, height: previewH)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .gesture(
                    SimultaneousGesture(dragGesture, pinchGesture)
                )
                .animation(.interactiveSpring(), value: offsetX)
                .animation(.interactiveSpring(), value: offsetY)
                .animation(.interactiveSpring(), value: scale)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray4))
                .frame(width: previewW, height: previewH)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
        }
    }

    // MARK: - ラベル文字列

    private var offsetXLabel: String {
        let pct = Int(offsetX * 100)
        if pct == 0 { return "中央" }
        return pct > 0 ? "右\(pct)%" : "左\(-pct)%"
    }

    private var offsetYLabel: String {
        let pct = Int(offsetY * 100)
        if pct == 0 { return "中央" }
        return pct > 0 ? "下\(pct)%" : "上\(-pct)%"
    }

    private var scaleLabel: String {
        String(format: "×%.2f", scale)
    }
}

// MARK: - Comparable clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
