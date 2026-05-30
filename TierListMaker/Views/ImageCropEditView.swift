import SwiftUI

/// 画像アイテムの切り取り範囲・拡大縮小を編集するビュー。
/// 写真アプリ風のフルスクリーン編集UI。
/// ImageItemEditSheet の NavigationStack 内に NavigationLink でプッシュして使う。
struct ImageCropEditView: View {

    // MARK: - Bindings

    @Binding var offsetX: CGFloat
    @Binding var offsetY: CGFloat
    @Binding var scale: CGFloat

    let cachedImage: UIImage?
    let itemSize: ItemSize

    var dismissSheet: (() -> Void)? = nil

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - 初期値（キャンセル用スナップショット）

    @State private var initialOffsetX: CGFloat = 0
    @State private var initialOffsetY: CGFloat = 0
    @State private var initialScale: CGFloat = 1.0

    // MARK: - Gesture State

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    @State private var isGesturing = false
    @State private var imageAspect: CGFloat = 1.0

    // MARK: - テーマ適応カラー

    private var canvasBg: Color        { Color(.secondarySystemBackground) }
    private var controlBg: Color       { Color(.systemBackground) }
    private var primaryColor: Color    { Color(.label) }
    private var secondaryColor: Color  { Color(.secondaryLabel) }
    private var separatorColor: Color  { Color(.separator) }
    private var gridColor: Color       { Color(.label).opacity(0.25) }
    private var badgeBg: Color         { Color(.systemGray3).opacity(0.85) }
    private var disabledColor: Color   { Color(.tertiaryLabel) }

    // MARK: - Computed

    private let scaleMin: CGFloat = 1.0
    private var hasCustomCrop: Bool { offsetX != 0 || offsetY != 0 || scale != 1.0 }

    private func maxAllowedOffset(scale s: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let fW = itemSize.width, fH = itemSize.height
        let frameAspect = fW / fH
        let (fillW, fillH): (CGFloat, CGFloat) = imageAspect > frameAspect
            ? (imageAspect * fH, fH)
            : (fW, fW / imageAspect)
        return (
            x: max(0, (s * fillW - fW) / 2 / fW),
            y: max(0, (s * fillH - fH) / 2 / fH)
        )
    }

    private var liveScale: CGFloat {
        (scale * pinchDelta).clamped(to: scaleMin...5.0)
    }

    private func liveOffset(frameW: CGFloat, frameH: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let (maxX, maxY) = maxAllowedOffset(scale: liveScale)
        return (
            x: (offsetX + dragDelta.width  / frameW).clamped(to: -maxX...maxX),
            y: (offsetY + dragDelta.height / frameH).clamped(to: -maxY...maxY)
        )
    }

    private func cropFrameSize(availableWidth w: CGFloat) -> CGSize {
        let maxH: CGFloat = 350
        let aspect = itemSize.width / itemSize.height
        let naturalH = w / aspect
        return naturalH <= maxH
            ? CGSize(width: w, height: naturalH)
            : CGSize(width: maxH * aspect, height: maxH)
    }

    // MARK: - Actions

    private func resetAll() {
        withAnimation(.spring()) { offsetX = 0; offsetY = 0; scale = 1.0 }
    }

    private func cancelEditing() {
        offsetX = initialOffsetX
        offsetY = initialOffsetY
        scale   = initialScale
        dismiss()
    }

    private func commitDrag(_ v: DragGesture.Value, fW: CGFloat, fH: CGFloat) {
        let (maxX, maxY) = maxAllowedOffset(scale: scale)
        offsetX = (offsetX + v.translation.width  / fW).clamped(to: -maxX...maxX)
        offsetY = (offsetY + v.translation.height / fH).clamped(to: -maxY...maxY)
        withAnimation(.easeOut(duration: 0.25)) { isGesturing = false }
    }

    private func commitPinch(_ v: CGFloat) {
        let newScale = (scale * v).clamped(to: scaleMin...5.0)
        scale = newScale
        let (maxX, maxY) = maxAllowedOffset(scale: newScale)
        offsetX = offsetX.clamped(to: -maxX...maxX)
        offsetY = offsetY.clamped(to: -maxY...maxY)
        withAnimation(.easeOut(duration: 0.25)) { isGesturing = false }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let cf = cropFrameSize(availableWidth: geo.size.width - 32)
            let fW = cf.width
            let fH = cf.height
            let ls = liveScale
            let lo = liveOffset(frameW: fW, frameH: fH)

            ZStack {
                canvasBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    cropCanvas(fW: fW, fH: fH, ls: ls, lo: lo)
                    Spacer(minLength: 12)
                    bottomControls(fW: fW, fH: fH)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("切り取り・拡大縮小")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { cancelEditing() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") { dismissSheet?() ?? dismiss() }
                    .bold()
            }
        }
        .onAppear {
            initialOffsetX = offsetX
            initialOffsetY = offsetY
            initialScale   = scale
            if let img = cachedImage, img.size.height > 0 {
                imageAspect = img.size.width / img.size.height
            }
        }
    }

    // MARK: - Crop Canvas

    @ViewBuilder
    private func cropCanvas(
        fW: CGFloat, fH: CGFloat,
        ls: CGFloat, lo: (x: CGFloat, y: CGFloat)
    ) -> some View {
        ZStack {
            Color(hex: "#AAAAAA")

            if let uiImage = cachedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(ls)
                    .offset(x: lo.x * itemSize.width, y: lo.y * itemSize.height)
            }

            CropGridOverlay(lineColor: gridColor)
                .opacity(isGesturing ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isGesturing)
        }
        .frame(width: fW, height: fH)
        .clipped()
        .overlay { Rectangle().strokeBorder(primaryColor.opacity(0.3), lineWidth: 0.5) }
        .overlay { CropCornerMarks(color: primaryColor) }
        .overlay(alignment: .topTrailing) {
            Text(String(format: "×%.2f", ls))
                .font(.caption2.monospacedDigit().bold())
                .foregroundColor(primaryColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(badgeBg)
                .clipShape(Capsule())
                .padding(8)
                .opacity(isGesturing ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isGesturing)
        }
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragDelta) { v, state, _ in state = v.translation }
                    .onChanged { _ in isGesturing = true }
                    .onEnded   { commitDrag($0, fW: fW, fH: fH) },
                MagnificationGesture()
                    .updating($pinchDelta) { v, state, _ in state = v }
                    .onChanged { _ in isGesturing = true }
                    .onEnded   { commitPinch($0) }
            )
        )
    }

    // MARK: - Bottom Controls

    @ViewBuilder
    private func bottomControls(fW: CGFloat, fH: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("ピンチで拡大・ドラッグで移動")
                .font(.caption)
                .foregroundColor(secondaryColor)
                .padding(.vertical, 12)

            HStack(spacing: 14) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(secondaryColor).font(.callout)

                Slider(
                    value: Binding(
                        get: { scale },
                        set: { v in
                            scale = v.clamped(to: scaleMin...5.0)
                            let (maxX, maxY) = maxAllowedOffset(scale: scale)
                            offsetX = offsetX.clamped(to: -maxX...maxX)
                            offsetY = offsetY.clamped(to: -maxY...maxY)
                        }
                    ),
                    in: scaleMin...5.0
                )

                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(secondaryColor).font(.callout)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)

            separatorColor.frame(height: 0.5)

            HStack(spacing: 0) {
                cropControlButton(
                    icon: "arrow.counterclockwise",
                    label: "リセット",
                    tint: hasCustomCrop ? primaryColor : disabledColor
                ) { resetAll() }
                .disabled(!hasCustomCrop)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
        }
        .background(controlBg)
    }

    private var controlSep: some View {
        separatorColor.frame(width: 0.5, height: 36)
    }

    @ViewBuilder
    private func cropControlButton(
        icon: String, label: String, tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.caption2)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3×3 グリッドオーバーレイ

struct CropGridOverlay: View {
    var lineColor: Color = Color(.label).opacity(0.25)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { path in
                for i in 1..<3 {
                    let x = w / 3 * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    let y = h / 3 * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
            }
            .stroke(lineColor, lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - コーナーマーク（写真アプリ風）

struct CropCornerMarks: View {
    var color: Color = Color(.label)
    private let len: CGFloat = 20
    private let thickness: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: 0, y: len))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: len, y: 0))
                path.move(to: CGPoint(x: w - len, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: len))
                path.move(to: CGPoint(x: w, y: h - len))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w - len, y: h))
                path.move(to: CGPoint(x: len, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h - len))
            }
            .stroke(color, lineWidth: thickness)
        }
        .allowsHitTesting(false)
    }
}
