import SwiftUI
import Photos

struct AddItemSheet: View {
    @ObservedObject var vm: TierListViewModel
    @Environment(\.dismiss) var dismiss

    @State private var labelText = ""
    @State private var showPhotoPicker = false
    @State private var showAddedFeedback = false
    @State private var showDismissAlert = false

    private var hasUnadded: Bool {
        !labelText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── テキストで追加 ──
                        VStack(alignment: .leading, spacing: 12) {
                            Label("テキストで追加", systemImage: "textformat")
                                .font(.headline)
                                .foregroundColor(.primary)

                            VStack(spacing: 0) {
                                TextField("アイテム名を入力", text: $labelText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemBackground))

                                Divider()
                                    .padding(.leading, 16)

                                Button {
                                    guard !labelText.isEmpty else { return }
                                    vm.addItem(label: labelText)
                                    labelText = ""
                                    showFeedback()
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("追加する")
                                            .bold()
                                    }
                                    .foregroundColor(labelText.isEmpty ? .secondary : .blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemBackground))
                                }
                                .disabled(labelText.isEmpty)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        }

                        // ── 写真で追加 ──
                        VStack(alignment: .leading, spacing: 12) {
                            Label("写真で追加", systemImage: "photo.on.rectangle")
                                .font(.headline)
                                .foregroundColor(.primary)

                            VStack(spacing: 0) {
                                Button {
                                    showPhotoPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "photo.stack")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("写真を選ぶ")
                                                .bold()
                                                .foregroundColor(.blue)
                                            Text("追加済みはグレーで表示されます")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemBackground))
                                }

                                // 追加済み枚数表示部分
                                if vm.addedAssetIds.count > 0 {
                                    Divider()
                                        .padding(.leading, 16)

                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("\(vm.addedAssetIds.count)枚追加済み")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemBackground))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }

                // ── 追加フィードバック ──
                if showAddedFeedback {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 90, height: 90)
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 1.2).combined(with: .opacity)
                        )
                    )
                }
            }
            .navigationTitle("アイテム追加")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if hasUnadded {
                            showDismissAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("未追加のアイテムがあります", isPresented: $showDismissAlert) {
                Button("追加せず閉じる", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("入力中のテキストが追加されていません。このまま閉じますか？")
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoGridPicker(addedAssetIds: $vm.addedAssetIds) { data in
                    vm.addItem(label: "", imageData: data)
                    showFeedback()
                }
            }
        }
    }

    private func showFeedback() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showAddedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showAddedFeedback = false
            }
        }
    }
}
