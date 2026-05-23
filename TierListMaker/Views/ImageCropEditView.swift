import SwiftUI

/// 画像アイテムの切り取り範囲・拡大縮小を編集するビュー。
/// ImageItemEditSheet の NavigationStack 内に NavigationLink でプッシュして使う。
struct ImageCropEditView: View {

    // MARK: - Bindings

    @Binding var offsetX: CGFloat       // 正規化：-1.0 〜 1.0（0が中央）
    @Binding var offsetY: CGFloat       // 正規化：-1.0 〜 1.0（0が中央）
    @Binding var scale: CGFloat         // 0.5 〜 5.0（containON 時は 1.0 以上）
    @Binding var cropContain: Bool      // true = グレーが出ない範囲に制限
    @Binding var cropTransparentBg: Bool // true = グレー部分を透明化（cropContain OFF 時のみ有効）

    let imageData: Data?
    let itemSize: ItemSize

    // MARK: - Gesture transient state

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    // MARK: - 画像アスペクト比（キャッシュ）

    @State private var imageAspect: CGFloat = 1.0

    // MARK: - プレビューサイズ

    private var displayScale: CGFloat {
        let maxSide: CGFloat = 270
        return maxSide / max(itemSize.width, itemSize.height)
    }
    private var previewW: CGFloat { itemSize.width  * displayScale }
    private var previewH: CGFloat { itemSize.height * displayScale }

    // MARK: - スケール範囲

    private var scaleMin: CGFloat { cropContain ? 1.0 : 0.5 }

    // MARK: - 最大許容オフセット（正規化）

    private func maxAllowedOffset(scale s: CGFloat) -> (x: CGFloat, y: CGFloat) {
        guard cropContain else { return (1.0, 1.0) }
        let fW = itemSize.width
        let fH = itemSize.height
        let frameAspect = fW / fH
        let fillW: CGFloat
        let fillH: CGFloat
        if imageAspect > frameAspect {
            fillH = fH
            fillW = imageAspect * fH
        } else {
            fillW = fW
            fillH = fW / imageAspect
        }
        let scaledW = s * fillW
        let scaledH = s * fillH
        return (
            x: max(0, (scaledW - fW) / 2.0 / fW),
            y: max(0, (scaledH - fH) / 2.0 / fH)
        )
    }

    // MARK: - ライブ値（ジェスチャー中の差分を加算し、範囲を丸める）

    private var liveScale: CGFloat {
        (scale * pinchDelta).clamped(to: scaleMin...5.0)
    }
    private var liveOffsetX: CGFloat {
        let (maxX, _) = maxAllowedOffset(scale: liveScale)
        return (offsetX + dragDelta.width / previewW).clamped(to: -maxX...maxX)
    }
    private var liveOffsetY: CGFloat {
        let (_, maxY) = maxAllowedOffset(scale: liveScale)
        return (offsetY + dragDelta.height / previewH).clamped(to: -maxY...maxY)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let (maxX, maxY) = maxAllowedOffset(scale: scale)
                offsetX = (offsetX + value.translation.width  / previewW).clamped(to: -maxX...maxX)
                offsetY = (offsetY + value.translation.height / previewH).clamped(to: -maxY...maxY)
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = (scale * value).clamped(to: scaleMin...5.0)
                scale = newScale
                // スケールが変わるとオフセット上限も変わるので再クランプ
                let (maxX, maxY) = maxAllowedOffset(scale: newScale)
                offsetX = offsetX.clamped(to: -maxX...maxX)
                offsetY = offsetY.clamped(to: -maxY...maxY)
            }
    }

    // MARK: - リセット

    private func resetAll() {
        withAnimation(.spring()) {
            offsetX = 0
            offsetY = 0
            scale   = 1.0
        }
    }

    private var hasCustomCrop: Bool {
        offsetX != 0 || offsetY != 0 || scale != 1.0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // ── プレビューエリア ──
            ZStack {
                Color(.systemGray6).ignoresSafeArea(edges: .top)

                VStack(spacing: 10) {
                    Text(cropContain ? "ドラッグで移動・ピンチで拡大縮小" : "ドラッグで移動・ピンチで拡大縮小")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    previewCanvas
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

            // ── 設定フォーム ──
            Form {

                // ── はみ出し制御 ──
                Section {
                    // はみ出し防止トグル
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("はみ出し防止")
                                    .font(.subheadline)
                                Text("オフにすると自由に移動・縮小できます")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "square.dashed")
                                .foregroundColor(.blue)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { cropContain },
                            set: { newVal in
                                cropContain = newVal
                                // オンオフを切り替えたら必ずデフォルトに戻す
                                resetAll()
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)

                    // 透明背景トグル（はみ出し防止 OFF 時のみ表示）
                    if !cropContain {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("背景を透明にする")
                                        .font(.subheadline)
                                    Text("グレーが出る部分を透明にします")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: "circle.dotted")
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Toggle("", isOn: $cropTransparentBg)
                                .labelsHidden()
                        }
                        .padding(.vertical, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                } header: {
                    Text("表示設定")
                }

                // ── リセット ──
                Section {
                    Button {
                        resetAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("デフォルトに戻す")
                        }
                        .foregroundColor(hasCustomCrop ? .red : .secondary)
                    }
                    .disabled(!hasCustomCrop)
                }

                // ── 水平位置 ──
                Section {
                    sliderRow(
                        label: "水平位置",
                        icon: "arrow.left.and.right",
                        valueLabel: offsetXLabel,
                        leadingIcon: "arrow.left",
                        trailingIcon: "arrow.right",
                        binding: Binding(
                            get: { offsetX },
                            set: { v in
                                let (maxX, _) = maxAllowedOffset(scale: scale)
                                offsetX = v.clamped(to: -maxX...maxX)
                            }
                        ),
                        range: {
                            let (maxX, _) = maxAllowedOffset(scale: scale)
                            return -maxX...maxX
                        }()
                    )
                }

                // ── 垂直位置 ──
                Section {
                    sliderRow(
                        label: "垂直位置",
                        icon: "arrow.up.and.down",
                        valueLabel: offsetYLabel,
                        leadingIcon: "arrow.up",
                        trailingIcon: "arrow.down",
                        binding: Binding(
                            get: { offsetY },
                            set: { v in
                                let (_, maxY) = maxAllowedOffset(scale: scale)
                                offsetY = v.clamped(to: -maxY...maxY)
                            }
                        ),
                        range: {
                            let (_, maxY) = maxAllowedOffset(scale: scale)
                            return -maxY...maxY
                        }()
                    )
                }

                // ── 拡大縮小 ──
                Section {
                    sliderRow(
                        label: "拡大縮小",
                        icon: "magnifyingglass",
                        valueLabel: scaleLabel,
                        leadingIcon: "minus.magnifyingglass",
                        trailingIcon: "plus.magnifyingglass",
                        binding: Binding(
                            get: { scale },
                            set: { v in
                                scale = v.clamped(to: scaleMin...5.0)
                                // スケール変更後にオフセット上限を再適用
                                let (maxX, maxY) = maxAllowedOffset(scale: scale)
                                offsetX = offsetX.clamped(to: -maxX...maxX)
                                offsetY = offsetY.clamped(to: -maxY...maxY)
                            }
                        ),
                        range: scaleMin...5.0
                    )
                } footer: {
                    if cropContain {
                        Text("はみ出し防止が ON のため、縮小（×1.0未満）は無効です")
                            .font(.caption)
                    }
                }
            }
            .animation(.spring(), value: cropContain)
        }
        .navigationTitle("切り取り・拡大縮小")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let data = imageData, let img = UIImage(data: data), img.size.height > 0 {
                imageAspect = img.size.width / img.size.height
            }
        }
    }

    // MARK: - プレビューキャンバス

    @ViewBuilder
    private var previewCanvas: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            ZStack {
                // 背景（透明設定の反映）
                if !cropContain && cropTransparentBg {
                    // 透明を視覚的に示すチェッカー
                    CheckerboardView()
                        .frame(width: previewW, height: previewH)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray4))
                        .frame(width: previewW, height: previewH)
                }

                // 画像
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(liveScale)
                    .offset(x: liveOffsetX * previewW, y: liveOffsetY * previewH)
                    .frame(width: previewW, height: previewH)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .gesture(SimultaneousGesture(dragGesture, pinchGesture))
            .animation(.interactiveSpring(), value: offsetX)
            .animation(.interactiveSpring(), value: offsetY)
            .animation(.interactiveSpring(), value: scale)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray4))
                .frame(width: previewW, height: previewH)
                .overlay(Image(systemName: "photo").foregroundColor(.secondary))
        }
    }

    // MARK: - 共通スライダー行

    @ViewBuilder
    private func sliderRow(
        label: String,
        icon: String,
        valueLabel: String,
        leadingIcon: String,
        trailingIcon: String,
        binding: Binding<CGFloat>,
        range: ClosedRange<CGFloat>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                Spacer()
                Text(valueLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Image(systemName: leadingIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                // range が空（min == max）のとき Slider がクラッシュするので guard
                if range.lowerBound < range.upperBound {
                    Slider(value: binding, in: range)
                } else {
                    Slider(value: binding, in: 0...1)
                        .disabled(true)
                        .opacity(0.4)
                }
                Image(systemName: trailingIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
        }
        .padding(.vertical, 4)
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

// MARK: - チェッカーボード（透明背景の視覚的表示）

struct CheckerboardView: View {
    private let tileSize: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            let cols = Int(ceil(size.width  / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    ctx.fill(
                        Path(CGRect(
                            x: CGFloat(col) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )),
                        with: .color(isLight ? Color(.systemGray5) : Color(.systemGray3))
                    )
                }
            }
        }
    }
}
