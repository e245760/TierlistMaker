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
    @State private var editedTextColor: Color
    @State private var editedBgColor: Color

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
        self._editedTextColor = State(initialValue: Color(hex: item.wrappedValue.textColorHex))
        self._editedBgColor   = State(initialValue: Color(hex: item.wrappedValue.backgroundColorHex))
    }

    // プレビュー用アイテム（サイズはグローバル設定を引き継ぎ）
    var previewItem: TierItem {
        TierItem(
            id: item.id,
            label: editedLabel,
            imageData: nil,
            itemSize: item.itemSize,
            textSize: item.textSize,
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

                    // 背景色
                    Section("背景色") {
                        colorGrid(colors: presetBgColors, selected: $editedBgColor)
                        customColorPicker(label: "カスタムカラー", selected: $editedBgColor)
                    }

                    // テキストカラー
                    Section("テキストカラー") {
                        colorGrid(colors: presetColors, selected: $editedTextColor)
                        customColorPicker(label: "カスタムカラー", selected: $editedTextColor)
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
                        item.textColorHex       = editedTextColor.toHex()
                        item.backgroundColorHex = editedBgColor.toHex()
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

    @State private var editedFlipH: Bool
    @State private var editedFlipV: Bool

    init(item: Binding<TierItem>) {
        self._item = item
        self._editedFlipH = State(initialValue: item.wrappedValue.isFlippedHorizontal)
        self._editedFlipV = State(initialValue: item.wrappedValue.isFlippedVertical)
    }

    var previewItem: TierItem {
        TierItem(
            id: item.id,
            label: item.label,
            imageData: item.imageData,
            itemSize: item.itemSize,
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
                            .animation(.spring(), value: editedFlipH)
                            .animation(.spring(), value: editedFlipV)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 130)

                Form {
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
