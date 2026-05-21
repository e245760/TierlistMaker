import SwiftUI

struct TierItemEditSheet: View {
    @Binding var item: TierItem
    @Environment(\.dismiss) var dismiss

    var isImageItem: Bool { item.imageData != nil }

    var body: some View {
        if isImageItem {
            ImageItemEditSheet(item: $item)
        } else {
            TextItemEditSheet(item: $item)
        }
    }
}

// ── テキストアイテム編集 ──
struct TextItemEditSheet: View {
    @Binding var item: TierItem
    @Environment(\.dismiss) var dismiss

    @State private var editedLabel: String
    @State private var editedTextSize: ItemTextSize
    @State private var editedTextColor: Color
    @State private var editedBgColor: Color
    @State private var editedSize: ItemSize

    private let maxLength = 12

    private let presetColors: [Color] = [
        Color(hex: "#000000"),
        Color(hex: "#FFFFFF"),
        Color(hex: "#FF3B30"),
        Color(hex: "#FF9500"),
        Color(hex: "#FFCC00"),
        Color(hex: "#34C759"),
        Color(hex: "#007AFF"),
        Color(hex: "#AF52DE"),
    ]

    private let presetBgColors: [Color] = [
        Color(hex: "#AAAAAA"),
        Color(hex: "#FF7F7F"),
        Color(hex: "#FFBF7F"),
        Color(hex: "#FFFF7F"),
        Color(hex: "#7FFF7F"),
        Color(hex: "#7FBFFF"),
        Color(hex: "#BF7FFF"),
        Color(hex: "#FF7FBF"),
    ]

    init(item: Binding<TierItem>) {
        self._item = item
        self._editedLabel     = State(initialValue: item.wrappedValue.label)
        self._editedTextSize  = State(initialValue: item.wrappedValue.textSize)
        self._editedTextColor = State(initialValue: Color(hex: item.wrappedValue.textColorHex))
        self._editedBgColor   = State(initialValue: Color(hex: item.wrappedValue.backgroundColorHex))
        self._editedSize      = State(initialValue: item.wrappedValue.itemSize)
    }

    // プレビュー用アイテム
    var previewItem: TierItem {
        TierItem(
            id: item.id,
            label: editedLabel,
            imageData: nil,
            itemSize: editedSize,
            textSize: editedTextSize,
            textColorHex: editedTextColor.toHex(),
            backgroundColorHex: editedBgColor.toHex()
        )
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
                            .animation(.spring(), value: editedSize)
                            .animation(.spring(), value: editedTextSize)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 130)

                Form {
                    // テキスト
                    Section("テキスト（最大\(maxLength)文字）") {
                        TextField("アイテム名", text: $editedLabel)
                            .autocorrectionDisabled(true)
                            .onChange(of: editedLabel) { newValue in
                                if newValue.count > maxLength {
                                    editedLabel = String(newValue.prefix(maxLength))
                                }
                            }
                    }

                    // アイテムサイズ
                    Section("アイテムサイズ") {
                        sizeSelector(selected: $editedSize)
                    }

                    // テキストサイズ
                    Section("テキストサイズ") {
                        HStack(spacing: 8) {
                            ForEach(ItemTextSize.allCases, id: \.self) { size in
                                let isSelected = editedTextSize == size
                                Button {
                                    withAnimation(.spring()) { editedTextSize = size }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("A")
                                            .font(.system(size: size.fontSize, weight: .bold))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .frame(height: 24)
                                        Text(size.label)
                                            .font(.system(size: 9).bold())
                                            .foregroundColor(isSelected ? .white : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isSelected ? Color.blue : Color(.systemGray5))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // テキストカラー
                    Section("テキストカラー") {
                        colorGrid(colors: presetColors, selected: $editedTextColor)
                        customColorPicker(label: "カスタムカラー", selected: $editedTextColor)
                    }

                    // 背景色
                    Section("背景色") {
                        colorGrid(colors: presetBgColors, selected: $editedBgColor)
                        customColorPicker(label: "カスタムカラー", selected: $editedBgColor)
                    }
                }
            }
            .navigationTitle("テキスト編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        item.label              = editedLabel
                        item.textSize           = editedTextSize
                        item.textColorHex       = editedTextColor.toHex()
                        item.backgroundColorHex = editedBgColor.toHex()
                        item.itemSize           = editedSize
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

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
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 3)
                            .padding(-3)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(
                                color.toHex() == "#FFFFFF" ? .black : .white
                            )
                            .shadow(radius: 1)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .onTapGesture {
                        withAnimation(.spring()) { selected.wrappedValue = color }
                    }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    func customColorPicker(label: String, selected: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            ColorPicker("", selection: selected, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, height: 44)
                .scaleEffect(1.3)
        }
        .padding(.bottom, 4)
    }
}

// ── 画像アイテム編集 ──
struct ImageItemEditSheet: View {
    @Binding var item: TierItem
    @Environment(\.dismiss) var dismiss

    @State private var editedSize: ItemSize
    @State private var editedFlipH: Bool
    @State private var editedFlipV: Bool

    init(item: Binding<TierItem>) {
        self._item = item
        self._editedSize  = State(initialValue: item.wrappedValue.itemSize)
        self._editedFlipH = State(initialValue: item.wrappedValue.isFlippedHorizontal)
        self._editedFlipV = State(initialValue: item.wrappedValue.isFlippedVertical)
    }

    var previewItem: TierItem {
        TierItem(
            id: item.id,
            label: item.label,
            imageData: item.imageData,
            itemSize: editedSize,
            isFlippedHorizontal: editedFlipH,
            isFlippedVertical: editedFlipV
        )
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
                            .animation(.spring(), value: editedSize)
                            .animation(.spring(), value: editedFlipH)
                            .animation(.spring(), value: editedFlipV)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 130)

                Form {
                    // アイテムサイズ
                    Section("アイテムサイズ") {
                        sizeSelector(selected: $editedSize)
                    }

                    // 反転
                    Section("反転") {
                        HStack(spacing: 12) {
                            // 左右反転
                            Button {
                                withAnimation(.spring()) { editedFlipH.toggle() }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                        .font(.title2)
                                        .foregroundColor(editedFlipH ? .white : .primary)
                                    Text("左右反転")
                                        .font(.caption.bold())
                                        .foregroundColor(editedFlipH ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(editedFlipH ? Color.blue : Color(.systemGray5))
                                )
                            }
                            .buttonStyle(.plain)

                            // 上下反転
                            Button {
                                withAnimation(.spring()) { editedFlipV.toggle() }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                                        .font(.title2)
                                        .foregroundColor(editedFlipV ? .white : .primary)
                                    Text("上下反転")
                                        .font(.caption.bold())
                                        .foregroundColor(editedFlipV ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(editedFlipV ? Color.blue : Color(.systemGray5))
                                )
                            }
                            .buttonStyle(.plain)
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
                        item.itemSize            = editedSize
                        item.isFlippedHorizontal = editedFlipH
                        item.isFlippedVertical   = editedFlipV
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// 共通のサイズ選択UI
@ViewBuilder
func sizeSelector(selected: Binding<ItemSize>) -> some View {
    HStack(spacing: 12) {
        ForEach(ItemSize.allCases, id: \.self) { size in
            let isSelected = selected.wrappedValue == size
            Button {
                withAnimation(.spring()) { selected.wrappedValue = size }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: size.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(size.label)
                        .font(.caption.bold())
                        .foregroundColor(isSelected ? .white : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
            }
            .buttonStyle(.plain)
        }
    }
    .padding(.vertical, 4)
}
