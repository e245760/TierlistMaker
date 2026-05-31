import SwiftUI

struct TierItemEditSheet: View {
    @Binding var item: TierItem
    @Environment(\.dismiss) var dismiss

    var isImageItem: Bool { item.imageFileName != nil }

    var body: some View {
        if isImageItem {
            ImageItemEditSheet(item: $item, dismissSheet: { dismiss() })
        } else {
            TextItemEditSheet(item: $item)
        }
    }
}

// ── テキストアイテム編集 ──
struct TextItemEditSheet: View {
    @Binding var item: TierItem
    @Environment(\.dismiss) var dismiss

    // PurchaseManager をシングルトンから直接参照（呼び出し元の変更不要）
    @EnvironmentObject private var pm: PurchaseManager

    @State private var editedLabel: String
    @State private var editedTextColor: Color
    @State private var editedBgColor: Color
    @State private var showPaywall = false          // ← Proバッジタップ時に表示
    @FocusState private var isLabelFocused: Bool

    private let maxLength = 12

    private let presetColors: [Color] = [
        Color(hex: "#000000"), Color(hex: "#FFFFFF"),
        Color(hex: "#FF3B30"), Color(hex: "#FF9500"),
        Color(hex: "#FFCC00"), Color(hex: "#34C759"),
        Color(hex: "#007AFF"), Color(hex: "#AF52DE"),
    ]

    private let presetBgColors: [Color] = [
        Color(hex: "#AAAAAA"), Color(hex: "#FF7F7F"),
        Color(hex: "#FFBF7F"), Color(hex: "#FFFF7F"),
        Color(hex: "#7FFF7F"), Color(hex: "#7FBFFF"),
        Color(hex: "#BF7FFF"), Color(hex: "#FF7FBF"),
    ]

    init(item: Binding<TierItem>) {
        self._item = item
        self._editedLabel     = State(initialValue: item.wrappedValue.label)
        self._editedTextColor = State(initialValue: Color(hex: item.wrappedValue.textColorHex))
        self._editedBgColor   = State(initialValue: Color(hex: item.wrappedValue.backgroundColorHex))
    }

    var previewItem: TierItem {
        TierItem(
            id: item.id,
            label: editedLabel,
            imageFileName: nil,
            itemSize: item.itemSize,
            textSize: item.textSize,
            textColorHex: editedTextColor.toHex(),
            backgroundColorHex: editedBgColor.toHex()
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color(.systemGray6).ignoresSafeArea(edges: .top)
                    VStack(spacing: 8) {
                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TierItemView(item: previewItem)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 130)

                Form {
                    Section("テキスト（最大\(maxLength)文字）") {
                        TextField("アイテム名", text: $editedLabel)
                            .autocorrectionDisabled(true)
                            .focused($isLabelFocused)
                            .onChange(of: editedLabel) { _, newValue in
                                if newValue.count > maxLength {
                                    editedLabel = String(newValue.prefix(maxLength))
                                }
                            }
                    }
                    Section("背景色") {
                        colorGrid(colors: presetBgColors, selected: $editedBgColor)
                        customColorPicker(label: "カスタムカラー", selected: $editedBgColor)
                    }
                    Section("テキストカラー") {
                        colorGrid(colors: presetColors, selected: $editedTextColor)
                        customColorPicker(label: "カスタムカラー", selected: $editedTextColor)
                    }
                }
            }
            .navigationTitle("テキスト編集")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isLabelFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        item.label              = editedLabel
                        item.textColorHex       = editedTextColor.toHex()
                        item.backgroundColorHex = editedBgColor.toHex()
                        dismiss()
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
        }
    }

    // MARK: - Color Grid（変更なし）

    @ViewBuilder
    func colorGrid(colors: [Color], selected: Binding<Color>) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: 12
        ) {
            ForEach(0..<colors.count, id: \.self) { i in
                let color = colors[i]
                let isSelected = selected.wrappedValue.toHex() == color.toHex()
                Circle()
                    .fill(color)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))
                    .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 3).padding(-3))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(color.toHex() == "#FFFFFF" ? .black : .white)
                            .shadow(radius: 1)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .onTapGesture { withAnimation(.spring()) { selected.wrappedValue = color } }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - カスタムカラーピッカー（Pro限定）
    //
    // isPro: ColorPicker をそのまま表示
    // 非Pro: 南京錠＋「Pro」バッジを表示し、タップでペイウォールを開く

    @ViewBuilder
    func customColorPicker(label: String, selected: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if pm.isPro {
                ColorPicker("", selection: selected, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
                    .scaleEffect(1.3)
            } else {
                proLockedBadge
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Pro ロックバッジ

    private var proLockedBadge: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.caption.bold())
                Text("Pro")
                    .font(.caption.bold())
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// ── 画像アイテム編集（変更なし）──
struct ImageItemEditSheet: View {
    @Binding var item: TierItem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var pm: PurchaseManager

    /// 完了タップ時にシートごと閉じるクロージャ（TierItemEditSheet から受け取る）
    var dismissSheet: (() -> Void)? = nil

    // 反転
    @State private var editedFlipH: Bool
    @State private var editedFlipV: Bool
    // クロップ
    @State private var editedCropOffsetX: CGFloat
    @State private var editedCropOffsetY: CGFloat
    @State private var editedCropScale: CGFloat
    // テキスト帯
    @State private var editedLabel: String
    @State private var editedTextColor: Color
    @State private var editedBgColor: Color
    @State private var showPaywall = false

    private let maxLength = 12

    private let cachedImage: UIImage?

    init(item: Binding<TierItem>, dismissSheet: (() -> Void)? = nil) {
        self._item = item
        self.dismissSheet = dismissSheet
        self._editedFlipH         = State(initialValue: item.wrappedValue.isFlippedHorizontal)
        self._editedFlipV         = State(initialValue: item.wrappedValue.isFlippedVertical)
        self._editedCropOffsetX   = State(initialValue: item.wrappedValue.cropOffsetX)
        self._editedCropOffsetY   = State(initialValue: item.wrappedValue.cropOffsetY)
        self._editedCropScale     = State(initialValue: item.wrappedValue.cropScale)
        self._editedLabel         = State(initialValue: item.wrappedValue.label)
        // ラベルが未設定（テキスト帯を初めて追加する）場合は
        // カラーグリッドの左上（テキスト: 白 / 帯背景: 黒）をデフォルトにする。
        // 既にテキストが設定されている場合は保存済みの色をそのまま使う。
        let hasLabel = !item.wrappedValue.label.isEmpty
        self._editedTextColor     = State(initialValue: hasLabel
            ? Color(hex: item.wrappedValue.textColorHex)
            : Color(hex: "#FFFFFF"))
        self._editedBgColor       = State(initialValue: hasLabel
            ? Color(hex: item.wrappedValue.backgroundColorHex)
            : Color(hex: "#000000"))

        if let name = item.wrappedValue.imageFileName {
            cachedImage = ImageFileStore.shared.load(fileName: name)
        } else {
            cachedImage = nil
        }
    }

    var previewItem: TierItem {
        TierItem(
            id: item.id,
            label: editedLabel,
            imageFileName: item.imageFileName,
            itemSize: item.itemSize,
            textSize: item.textSize,
            textColorHex: editedTextColor.toHex(),
            backgroundColorHex: editedBgColor.toHex(),
            isFlippedHorizontal: editedFlipH,
            isFlippedVertical: editedFlipV,
            cropOffsetX: editedCropOffsetX,
            cropOffsetY: editedCropOffsetY,
            cropScale: editedCropScale
        )
    }

    private var hasCustomCrop: Bool {
        editedCropOffsetX != 0 || editedCropOffsetY != 0 || editedCropScale != 1.0
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── プレビュー ──
                ZStack {
                    Color(.systemGray6).ignoresSafeArea(edges: .top)
                    VStack(spacing: 8) {
                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TierItemView(item: previewItem)
                            .animation(.spring(), value: editedFlipH)
                            .animation(.spring(), value: editedFlipV)
                            .animation(.spring(), value: editedCropOffsetX)
                            .animation(.spring(), value: editedCropOffsetY)
                            .animation(.spring(), value: editedCropScale)
                            .animation(.spring(), value: editedLabel)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 130)

                Form {

                    // ── テキスト帯 ──
                    Section("テキスト帯（最大\(maxLength)文字）") {
                        TextField("画像に重ねるテキスト（省略可）", text: $editedLabel)
                            .autocorrectionDisabled(true)
                            .onChange(of: editedLabel) { _, newValue in
                                if newValue.count > maxLength {
                                    editedLabel = String(newValue.prefix(maxLength))
                                }
                            }
                    }

                    // ── テキスト・帯の色（テキストがある場合のみ） ──
                    if !editedLabel.isEmpty {
                        Section("テキストカラー") {
                            colorGrid(colors: [
                                Color(hex: "#FFFFFF"), Color(hex: "#000000"),
                                Color(hex: "#FF3B30"), Color(hex: "#FF9500"),
                                Color(hex: "#FFCC00"), Color(hex: "#34C759"),
                                Color(hex: "#007AFF"), Color(hex: "#AF52DE"),
                            ], selected: $editedTextColor)
                            customColorPicker(label: "カスタムカラー", selected: $editedTextColor)
                        }
                        Section("帯の背景色") {
                            colorGrid(colors: [
                                Color(hex: "#000000"), Color(hex: "#FFFFFF"),
                                Color(hex: "#FF7F7F"), Color(hex: "#FFBF7F"),
                                Color(hex: "#FFFF7F"), Color(hex: "#7FFF7F"),
                                Color(hex: "#7FBFFF"), Color(hex: "#BF7FFF"),
                            ], selected: $editedBgColor)
                            customColorPicker(label: "カスタムカラー", selected: $editedBgColor)
                        }
                    }

                    // ── 切り取り・拡大縮小 ──
                    Section("切り取り・拡大縮小") {
                        NavigationLink {
                            ImageCropEditView(
                                offsetX: $editedCropOffsetX,
                                offsetY: $editedCropOffsetY,
                                scale: $editedCropScale,
                                cachedImage: cachedImage,
                                itemSize: item.itemSize,
                                dismissSheet: {
                                    item.isFlippedHorizontal = editedFlipH
                                    item.isFlippedVertical   = editedFlipV
                                    item.cropOffsetX         = editedCropOffsetX
                                    item.cropOffsetY         = editedCropOffsetY
                                    item.cropScale           = editedCropScale
                                    dismissSheet?()
                                }
                            )
                        } label: {
                            HStack {
                                Label("切り取り範囲を編集", systemImage: "crop.rotate")
                                Spacer()
                                if hasCustomCrop {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    // ── 反転 ──
                    Section("反転") {
                        HStack(spacing: 12) {
                            flipButton(
                                label: "左右反転",
                                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                isOn: $editedFlipH
                            )
                            flipButton(
                                label: "上下反転",
                                icon: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                                isOn: $editedFlipV
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("画像編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        item.label               = editedLabel
                        item.textColorHex        = editedTextColor.toHex()
                        item.backgroundColorHex  = editedBgColor.toHex()
                        item.isFlippedHorizontal = editedFlipH
                        item.isFlippedVertical   = editedFlipV
                        item.cropOffsetX         = editedCropOffsetX
                        item.cropOffsetY         = editedCropOffsetY
                        item.cropScale           = editedCropScale
                        if let dismissSheet {
                            dismissSheet()
                        } else {
                            dismiss()
                        }
                    }
                    .bold()
                }
            }
        }
    }

    @ViewBuilder
    private func flipButton(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.spring()) { isOn.wrappedValue.toggle() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isOn.wrappedValue ? .white : .primary)
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(isOn.wrappedValue ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn.wrappedValue ? Color.blue : Color(.systemGray4))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func colorGrid(colors: [Color], selected: Binding<Color>) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: 4),
            spacing: 12
        ) {
            ForEach(0..<colors.count, id: \.self) { i in
                let color = colors[i]
                let isSelected = selected.wrappedValue.toHex() == color.toHex()
                Circle()
                    .fill(color)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1))
                    .overlay(Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 3).padding(-3))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(color.toHex() == "#FFFFFF" ? .black : .white)
                            .shadow(radius: 1)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .onTapGesture { withAnimation(.spring()) { selected.wrappedValue = color } }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func customColorPicker(label: String, selected: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if pm.isPro {
                ColorPicker("", selection: selected, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
                    .scaleEffect(1.3)
            } else {
                proLockedBadge
            }
        }
        .padding(.bottom, 4)
    }

    private var proLockedBadge: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.caption.bold())
                Text("Pro")
                    .font(.caption.bold())
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
