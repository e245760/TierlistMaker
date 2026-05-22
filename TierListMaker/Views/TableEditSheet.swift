import SwiftUI

struct TableEditSheet: View {
    @ObservedObject var vm: TierListViewModel
    @Environment(\.dismiss) var dismiss

    // テーマ関連
    @AppStorage("appTheme") private var appTheme: AppTheme = .light
    @Environment(\.setAppTheme) private var setAppTheme

    @State private var editedLabelSize: LabelSize
    @State private var editedItemSize: ItemSize

    init(vm: TierListViewModel) {
        self.vm = vm
        self._editedLabelSize = State(initialValue: vm.defaultLabelSize)
        self._editedItemSize  = State(initialValue: vm.defaultItemSize)
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
                                .font(.title2.bold())
                                .frame(width: editedLabelSize.width)
                                .frame(height: 65)
                                .background(Color(hex: "#FF7F7F"))
                                .foregroundColor(.black)

                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { _ in
                                    let previewItem = TierItem(
                                        label: "A",
                                        itemSize: editedItemSize
                                    )
                                    TierItemView(item: previewItem)
                                }
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, minHeight: 65)
                            .background(Color(.systemGray5))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                        .padding(.horizontal, 24)
                        .animation(.spring(), value: editedLabelSize)
                        .animation(.spring(), value: editedItemSize)
                    }
                    .padding(.vertical, 16)
                }
                .frame(height: 150)

                Form {

                    // ── テーマ ──
                    Section("テーマ") {
                        HStack(spacing: 12) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                let isSelected = appTheme == theme
                                Button {
                                    withAnimation(.spring()) {
                                        setAppTheme(theme)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: theme.icon)
                                            .font(.title2)
                                            .foregroundColor(
                                                isSelected ? .white : .primary
                                            )
                                        Text(theme.label)
                                            .font(.caption.bold())
                                            .foregroundColor(
                                                isSelected ? .white : .primary
                                            )
                                    }
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

                    // ── ラベルサイズ ──
                    Section("ラベルサイズ（全行に適用）") {
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

                    // ── アイテムサイズ ──
                    Section("アイテムサイズ（全アイテムに適用）") {
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
                        vm.applyItemSizeToAll(editedItemSize)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
