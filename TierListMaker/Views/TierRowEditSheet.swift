import SwiftUI

struct TierRowEditSheet: View {
    @Binding var row: TierRow
    @Environment(\.dismiss) var dismiss

    @State private var editedName: String
    @State private var editedColor: Color
    @State private var editedLabelSize: LabelSize
    @State private var editedTextSize: LabelTextSize

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

    init(row: Binding<TierRow>) {
        self._row = row
        self._editedName      = State(initialValue: row.wrappedValue.tierName)
        self._editedColor     = State(initialValue: Color(hex: row.wrappedValue.color))
        self._editedLabelSize = State(initialValue: row.wrappedValue.labelSize)
        self._editedTextSize  = State(initialValue: row.wrappedValue.labelTextSize)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── 常に表示されるラベルプレビュー ──
                ZStack {
                    Color(.systemGray6).ignoresSafeArea(edges: .top)

                    VStack(spacing: 8) {
                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 0) {
                            Text(editedName.isEmpty ? "?" : editedName)
                                .font(.system(size: editedTextSize.fontSize, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: editedLabelSize.width)
                                .frame(height: 60)
                                .background(editedColor)
                                .foregroundColor(.black)

                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 60)
                                .overlay(
                                    Text("アイテムエリア")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                        .padding(.horizontal, 24)
                        .animation(.spring(), value: editedLabelSize)
                        .animation(.spring(), value: editedTextSize)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 130)

                // ── フォーム ──
                Form {

                    // ラベルテキスト
                    Section("ラベルテキスト（最大\(TierRow.maxLabelLength)文字）") {
                        TextField("S, A, B ...", text: $editedName)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .onChange(of: editedName) { newValue in
                                if newValue.count > TierRow.maxLabelLength {
                                    editedName = String(newValue.prefix(TierRow.maxLabelLength))
                                }
                            }
                    }

                    // ラベルサイズ
                    Section("ラベルサイズ") {
                        HStack(spacing: 12) {
                            ForEach(LabelSize.allCases, id: \.self) { size in
                                let isSelected = editedLabelSize == size
                                Button {
                                    withAnimation(.spring()) { editedLabelSize = size }
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

                    // テキストサイズ
                    Section("テキストサイズ") {
                        HStack(spacing: 8) {
                            ForEach(LabelTextSize.allCases, id: \.self) { size in
                                let isSelected = editedTextSize == size
                                Button {
                                    withAnimation(.spring()) { editedTextSize = size }
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("A")
                                            .font(.system(size: size.fontSize, weight: .bold))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .frame(height: 28)
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

                    // ラベルの色
                    Section("ラベルの色") {
                        VStack(spacing: 16) {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible()), count: 4),
                                spacing: 12
                            ) {
                                ForEach(0..<presetColors.count, id: \.self) { i in
                                    let color = presetColors[i].1
                                    let isSelected = editedColor.toHex() == color.toHex()

                                    Circle()
                                        .fill(color)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    isSelected ? Color.primary : Color.clear,
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
                                            withAnimation(.spring()) { editedColor = color }
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
                }
            }
            .navigationTitle("ラベルを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                            row.tierName = editedName
                        }
                        row.color         = editedColor.toHex()
                        row.labelSize     = editedLabelSize
                        row.labelTextSize = editedTextSize
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
