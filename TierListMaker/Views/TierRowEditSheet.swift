import SwiftUI

struct TierRowEditSheet: View {

    @Binding var row: TierRow
    @Environment(\.dismiss) var dismiss

    @State private var editedName: String
    @State private var editedColor: Color

    @State private var editedLabelSize: LabelSize?
    @State private var editedTextSize: LabelTextSize?
    @State private var editedTextColor: Color
    @State private var editedRowItemSize: ItemSize?

    let vm: TierListViewModel

    private let presetColors: [(String, Color)] = [
        ("S", Color(hex: "#FF7F7F")),
        ("A", Color(hex: "#FFBF7F")),
        ("B", Color(hex: "#FFFF7F")),
        ("C", Color(hex: "#7FFF7F")),
        ("D", Color(hex: "#7FBFFF")),
        ("+", Color(hex: "#BF7FFF")),
        ("+", Color(hex: "#FF7FBF")),
        ("+", Color(hex: "#7FFFFF")),
    ]

    init(row: Binding<TierRow>, vm: TierListViewModel) {

        self._row = row
        self.vm = vm

        self._editedName = State(
            initialValue: row.wrappedValue.tierName
        )

        self._editedColor = State(
            initialValue: Color(hex: row.wrappedValue.color)
        )

        self._editedTextColor = State(
            initialValue: Color(hex: row.wrappedValue.textColorHex)
        )

        self._editedLabelSize = State(
            initialValue: row.wrappedValue.labelSizeOverride
        )

        self._editedTextSize = State(
            initialValue: row.wrappedValue.labelTextSizeOverride
        )

        self._editedRowItemSize = State(
            initialValue: row.wrappedValue.rowItemSizeOverride
        )
    }

    var body: some View {

        let effectiveLabelSize =
            editedLabelSize ?? vm.defaultLabelSize

        let effectiveTextSize =
            editedTextSize ?? .medium

        let effectiveItemSize =
            editedRowItemSize ?? vm.defaultItemSize

        NavigationStack {

            VStack(spacing: 0) {

                // ── プレビュー ──
                ZStack {

                    Color(.systemGray6)
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 8) {

                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 0) {

                            // ラベル
                            Text(editedName.isEmpty ? "?" : editedName)
                                .font(
                                    .system(
                                        size: effectiveTextSize.fontSize,
                                        weight: .bold
                                    )
                                )
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: effectiveLabelSize.width)
                                .frame(height: 65)
                                .background(editedColor)
                                .foregroundColor(editedTextColor)

                            // アイテム
                            HStack(spacing: 4) {

                                ForEach(0..<2, id: \.self) { _ in

                                    let previewItem = TierItem(
                                        label: "A",
                                        itemSize: effectiveItemSize
                                    )

                                    TierItemView(item: previewItem)
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, minHeight: 65)
                            .background(Color(.systemGray5))
                        }
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                        .shadow(
                            color: .black.opacity(0.1),
                            radius: 4
                        )
                        .padding(.horizontal, 24)
                        .animation(.spring(), value: effectiveLabelSize)
                        .animation(.spring(), value: effectiveTextSize)
                        .animation(.spring(), value: effectiveItemSize)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 150)

                Form {

                    // ── ラベルテキスト ──
                    Section("ラベルテキスト（最大\(TierRow.maxLabelLength)文字）") {

                        TextField(
                            "S, A, B ...",
                            text: $editedName
                        )
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onChange(of: editedName) { newValue in

                            if newValue.count > TierRow.maxLabelLength {

                                editedName = String(
                                    newValue.prefix(TierRow.maxLabelLength)
                                )
                            }
                        }
                    }

                    // ── テキストサイズ ──
                    Section("テキストサイズ") {

                        let isUsingDefault =
                            editedTextSize == nil

                        HStack(spacing: 8) {

                            // デフォルト
                            Button {

                                withAnimation(.spring()) {
                                    editedTextSize = nil
                                }

                            } label: {

                                VStack(spacing: 4) {

                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.title3)

                                    Text("デフォルト")
                                        .font(.caption.bold())

                                    Text("中")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(
                                    isUsingDefault
                                    ? .white
                                    : .primary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            isUsingDefault
                                            ? Color.blue
                                            : Color.blue.opacity(0.15)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            // 個別
                            ForEach(LabelTextSize.allCases, id: \.self) { size in

                                let isSelected =
                                    editedTextSize == size

                                Button {

                                    withAnimation(.spring()) {
                                        editedTextSize = size
                                    }

                                } label: {

                                    VStack(spacing: 4) {

                                        Text("A")
                                            .font(
                                                .system(
                                                    size: size.fontSize,
                                                    weight: .bold
                                                )
                                            )

                                        Text(size.label)
                                            .font(.system(size: 9).bold())
                                    }
                                    .foregroundColor(
                                        isSelected
                                        ? .white
                                        : .primary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                isSelected
                                                ? Color.blue
                                                : Color(.systemGray5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // ── ラベルサイズ ──
                    Section("ラベルサイズ") {

                        let isUsingDefault =
                            editedLabelSize == nil

                        HStack(spacing: 12) {

                            // デフォルト
                            Button {

                                withAnimation(.spring()) {
                                    editedLabelSize = nil
                                }

                            } label: {

                                VStack(spacing: 6) {

                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.title2)

                                    Text("デフォルト")
                                        .font(.caption.bold())

                                    Text(vm.defaultLabelSize.label)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(
                                    isUsingDefault
                                    ? .white
                                    : .primary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isUsingDefault
                                            ? Color.blue
                                            : Color.blue.opacity(0.15)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            // 個別
                            ForEach(LabelSize.allCases, id: \.self) { size in

                                let isSelected =
                                    editedLabelSize == size

                                Button {

                                    withAnimation(.spring()) {
                                        editedLabelSize = size
                                    }

                                } label: {

                                    VStack(spacing: 6) {

                                        Image(systemName: size.icon)
                                            .font(.title2)

                                        Text(size.label)
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(
                                        isSelected
                                        ? .white
                                        : .primary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                isSelected
                                                ? Color.blue
                                                : Color(.systemGray5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // ── アイテムサイズ ──
                    Section("この行のアイテムサイズ") {

                        let isUsingDefault =
                            editedRowItemSize == nil

                        HStack(spacing: 12) {

                            // デフォルト
                            Button {

                                withAnimation(.spring()) {
                                    editedRowItemSize = nil
                                }

                            } label: {

                                VStack(spacing: 6) {

                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.title2)

                                    Text("デフォルト")
                                        .font(.caption.bold())

                                    Text(vm.defaultItemSize.label)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(
                                    isUsingDefault
                                    ? .white
                                    : .primary
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            isUsingDefault
                                            ? Color.blue
                                            : Color.blue.opacity(0.15)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            // 個別
                            ForEach(ItemSize.allCases, id: \.self) { size in

                                let isSelected =
                                    editedRowItemSize == size

                                Button {

                                    withAnimation(.spring()) {
                                        editedRowItemSize = size
                                    }

                                } label: {

                                    VStack(spacing: 6) {

                                        Image(systemName: size.icon)
                                            .font(.title2)

                                        Text(size.label)
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(
                                        isSelected
                                        ? .white
                                        : .primary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(
                                                isSelected
                                                ? Color.blue
                                                : Color(.systemGray5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // ── ラベルカラー ──
                    Section("ラベルの色") {

                        VStack(spacing: 16) {

                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible()),
                                    count: 4
                                ),
                                spacing: 12
                            ) {

                                ForEach(0..<presetColors.count, id: \.self) { i in

                                    let color = presetColors[i].1

                                    let isSelected =
                                        editedColor.toHex() == color.toHex()

                                    Circle()
                                        .fill(color)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    isSelected
                                                    ? Color.primary
                                                    : Color.clear,
                                                    lineWidth: 3
                                                )
                                                .padding(-3)
                                        )
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                                .shadow(radius: 1)
                                                .opacity(isSelected ? 1 : 0)
                                        )
                                        .onTapGesture {

                                            withAnimation(.spring()) {
                                                editedColor = color
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 8)

                            Divider()

                            HStack {

                                Text("カスタムカラー")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Spacer()

                                ColorPicker(
                                    "",
                                    selection: $editedColor,
                                    supportsOpacity: false
                                )
                                .labelsHidden()
                                .frame(width: 48, height: 48)
                                .scaleEffect(1.4)
                            }
                            .padding(.bottom, 4)
                        }
                    }

                    // ── テキストカラー ──
                    Section("テキストカラー") {

                        let presetTextColors: [Color] = [
                            Color(hex: "#000000"),
                            Color(hex: "#FFFFFF"),
                            Color(hex: "#FF3B30"),
                            Color(hex: "#FF9500"),
                            Color(hex: "#FFCC00"),
                            Color(hex: "#34C759"),
                            Color(hex: "#007AFF"),
                            Color(hex: "#AF52DE"),
                        ]

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible()),
                                count: 4
                            ),
                            spacing: 12
                        ) {

                            ForEach(0..<presetTextColors.count, id: \.self) { i in

                                let color = presetTextColors[i]

                                let isSelected =
                                    editedTextColor.toHex() == color.toHex()

                                Circle()
                                    .fill(color)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                Color.primary.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                isSelected
                                                ? Color.primary
                                                : Color.clear,
                                                lineWidth: 3
                                            )
                                            .padding(-3)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(
                                                color.toHex() == "#FFFFFF"
                                                ? .black
                                                : .white
                                            )
                                            .shadow(radius: 1)
                                            .opacity(isSelected ? 1 : 0)
                                    )
                                    .onTapGesture {

                                        withAnimation(.spring()) {
                                            editedTextColor = color
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)

                        HStack {

                            Text("カスタムカラー")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            ColorPicker(
                                "",
                                selection: $editedTextColor,
                                supportsOpacity: false
                            )
                            .labelsHidden()
                            .frame(width: 48, height: 48)
                            .scaleEffect(1.4)
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
            .navigationTitle("ラベルを編集")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("完了") {

                        if !editedName
                            .trimmingCharacters(in: .whitespaces)
                            .isEmpty {

                            row.tierName = editedName
                        }

                        row.color = editedColor.toHex()
                        row.textColorHex = editedTextColor.toHex()

                        row.labelSizeOverride = editedLabelSize
                        row.labelTextSizeOverride = editedTextSize
                        row.rowItemSizeOverride = editedRowItemSize

                        let appliedSize =
                            editedRowItemSize ?? vm.defaultItemSize

                        for i in row.items.indices {
                            row.items[i].itemSize = appliedSize
                        }

                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
