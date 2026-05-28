import SwiftUI

struct TierRowEditSheet: View {

    @Binding var row: TierRow
    @Environment(\.dismiss) var dismiss

    // TierThemeのcolorSchemeに上書きされた環境を、
    // アプリのテーマで正しく戻すために取得する
    @Environment(\.appTheme) private var appTheme

    // PurchaseManager をシングルトンから直接参照（呼び出し元の変更不要）
    @EnvironmentObject private var pm: PurchaseManager

    @State private var editedName: String
    @State private var editedColor: Color
    @State private var editedTextColor: Color
    @State private var showPaywall = false
    @State private var showDeleteAlert = false

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
        self._editedName      = State(initialValue: row.wrappedValue.tierName)
        self._editedColor     = State(initialValue: Color(hex: row.wrappedValue.color))
        self._editedTextColor = State(initialValue: Color(hex: row.wrappedValue.textColorHex))
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
                        HStack(spacing: 0) {
                            Text(editedName.isEmpty ? "?" : editedName)
                                .font(.system(size: vm.defaultLabelTextSize.fontSize, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: vm.defaultLabelSize.width)
                                .frame(maxHeight: .infinity)
                                .background(editedColor)
                                .foregroundColor(editedTextColor)
                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { _ in
                                    TierItemView(item: TierItem(
                                        label: "A",
                                        itemSize: vm.defaultItemSize,
                                        textSize: vm.defaultItemTextSize
                                    ))
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, minHeight: 65)
                            .background(Color(.systemGray5))
                        }
                        .frame(height: 65)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 150)

                Form {

                    // ── ラベルテキスト ──
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

                    // ── ラベルカラー ──
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

                            // カスタムカラー（Pro限定）
                            customColorRow(label: "カスタムカラー", selected: $editedColor)
                        }
                    }

                    // ── テキストカラー ──
                    Section("テキストカラー") {
                        let presetTextColors: [Color] = [
                            Color(hex: "#000000"), Color(hex: "#FFFFFF"),
                            Color(hex: "#FF3B30"), Color(hex: "#FF9500"),
                            Color(hex: "#FFCC00"), Color(hex: "#34C759"),
                            Color(hex: "#007AFF"), Color(hex: "#AF52DE"),
                        ]
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 4),
                            spacing: 12
                        ) {
                            ForEach(0..<presetTextColors.count, id: \.self) { i in
                                let color = presetTextColors[i]
                                let isSelected = editedTextColor.toHex() == color.toHex()
                                Circle()
                                    .fill(color)
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                                    )
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
                                            .foregroundColor(
                                                color.toHex() == "#FFFFFF" ? .black : .white
                                            )
                                            .shadow(radius: 1)
                                            .opacity(isSelected ? 1 : 0)
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring()) { editedTextColor = color }
                                    }
                            }
                        }
                        .padding(.vertical, 8)

                        // カスタムカラー（Pro限定）
                        customColorRow(label: "カスタムカラー", selected: $editedTextColor)
                    }
                }
            }
            .navigationTitle("ラベルを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                // 削除ボタン（中央左寄り）
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("この行を削除", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        if !editedName.trimmingCharacters(in: .whitespaces).isEmpty {
                            row.tierName = editedName
                        }
                        row.color        = editedColor.toHex()
                        row.textColorHex = editedTextColor.toHex()
                        dismiss()
                    }
                    .bold()
                }
            }
            .alert("この行を削除しますか？", isPresented: $showDeleteAlert) {
                Button("削除", role: .destructive) {
                    dismiss()
                    // dismiss後に削除することでバインディングの解放順序を安全にする
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring()) { vm.removeRow(id: row.id) }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この行のアイテムはすべてプールに戻されます。この操作は取り消せません。")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
        }
        // TierRowViewはTierThemeのcolorSchemeが適用されたスコープ内にあるため、
        // そこから開かれるシートもそのcolorSchemeを引き継いでしまう。
        // アプリのテーマで明示的に上書きして正しいテーマを適用する。
        .environment(\.colorScheme, appTheme.colorScheme)
    }

    // MARK: - カスタムカラー行（Pro限定）
    //
    // isPro: ColorPicker をそのまま表示
    // 非Pro: 南京錠＋「Pro」バッジを表示し、タップでペイウォールを開く

    @ViewBuilder
    private func customColorRow(label: String, selected: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if pm.isPro {
                ColorPicker("", selection: selected, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 48, height: 48)
                    .scaleEffect(1.4)
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
