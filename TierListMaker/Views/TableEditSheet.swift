import SwiftUI

struct TableEditSheet: View {
    @ObservedObject var vm: TierListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var editedLabelSize: LabelSize
    @State private var editedLabelTextSize: LabelTextSize
    @State private var editedItemSize: ItemSize
    @State private var editedItemTextSize: ItemTextSize
    @State private var editedTierTheme: TierTheme

    init(vm: TierListViewModel) {
        self.vm = vm
        self._editedLabelSize     = State(initialValue: vm.defaultLabelSize)
        self._editedLabelTextSize = State(initialValue: vm.defaultLabelTextSize)
        self._editedItemSize      = State(initialValue: vm.defaultItemSize)
        self._editedItemTextSize  = State(initialValue: vm.defaultItemTextSize)
        self._editedTierTheme     = State(initialValue: vm.tierTheme)
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
                            Text("S")
                                .font(.system(size: editedLabelTextSize.fontSize, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: editedLabelSize.width)
                                .frame(height: 65)
                                .background(Color(hex: "#FF7F7F"))
                                .foregroundColor(.black)

                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { _ in
                                    TierItemView(item: TierItem(
                                        label: "A",
                                        itemSize: editedItemSize,
                                        textSize: editedItemTextSize
                                    ))
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, minHeight: 65)
                            .background(editedTierTheme.rowBackground)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                        .padding(.horizontal, 24)
                        .animation(.spring(), value: editedLabelSize)
                        .animation(.spring(), value: editedLabelTextSize)
                        .animation(.spring(), value: editedItemSize)
                        .animation(.spring(), value: editedItemTextSize)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 150)
                .environment(\.colorScheme, editedTierTheme.colorScheme)

                Form {

                    // ── この表のテーマ ──
                    Section("この表のテーマ") {
                        // TierTheme.allCases を使うため、テーマを追加するとここが自動で更新される
                        let columns = Array(
                            repeating: GridItem(.flexible(), spacing: 10),
                            count: min(TierTheme.allCases.count, 3)
                        )
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(TierTheme.allCases, id: \.self) { theme in
                                let isSelected = editedTierTheme == theme
                                Button {
                                    withAnimation(.spring()) { editedTierTheme = theme }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: theme.icon)
                                            .font(.title2)
                                            .foregroundColor(isSelected ? .white : .primary)
                                        Text(theme.displayName)
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

                    // ── ラベルサイズ ──
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

                    // ── ラベルテキストサイズ ──
                    Section("ラベルテキストサイズ") {
                        HStack(spacing: 8) {
                            ForEach(LabelTextSize.allCases, id: \.self) { size in
                                let isSelected = editedLabelTextSize == size
                                Button {
                                    withAnimation(.spring()) { editedLabelTextSize = size }
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

                    // ── アイテムサイズ ──
                    Section("アイテムサイズ") {
                        HStack(spacing: 12) {
                            ForEach(ItemSize.allCases, id: \.self) { size in
                                let isSelected = editedItemSize == size
                                Button {
                                    withAnimation(.spring()) { editedItemSize = size }
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

                    // ── アイテムテキストサイズ ──
                    Section("アイテムテキストサイズ") {
                        HStack(spacing: 8) {
                            ForEach(ItemTextSize.allCases, id: \.self) { size in
                                let isSelected = editedItemTextSize == size
                                Button {
                                    withAnimation(.spring()) { editedItemTextSize = size }
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
                }
            }
            .navigationTitle("表の全体編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        vm.applyLabelSizeToAll(editedLabelSize)
                        vm.applyLabelTextSizeToAll(editedLabelTextSize)
                        vm.applyItemSizeToAll(editedItemSize)
                        vm.applyItemTextSizeToAll(editedItemTextSize)
                        vm.tierTheme = editedTierTheme
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
